import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/api_exception.dart';
import '../services/auth_service.dart';
import '../state/auth_state.dart';
import '../state/referral_state.dart';
import '../theme/app_theme.dart';
import '../widgets/auth_header.dart';
import '../widgets/referral_code_field.dart';

/// Matches the login screen's layout: primary-color hero + rounded sheet
/// with a Login/Register tab pill (Register active here; Login pops back).
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

/// Fields that render their own server error; anything else goes in the
/// banner.
const _shownFields = {'name', 'country_iso', 'phone', 'email', 'password', 'password_confirmation', 'referral_code'};

/// Pre-selected in the country picker when the API offers it.
const _defaultCountryIso = 'BD';

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  /// Pre-filled from a /ref/{CODE} deep link (parked in ReferralState) or
  /// a scanned QR.
  final _referralController = TextEditingController(text: ReferralState.instance.pendingCode ?? '');
  bool _isSubmitting = false;
  String? _error;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  bool _isLoadingCountries = true;
  bool _countriesFailed = false;
  List<Map> _countries = [];
  String? _selectedCountryIso;

  /// Per-field messages from a 422 (`errors: {phone: [...]}`), shown under
  /// the matching input rather than squashed into one banner line.
  Map<String, String> _fieldErrors = {};

  @override
  void initState() {
    super.initState();
    _loadCountries();
  }

  /// `country_iso` is required by the backend, so without this list the
  /// form cannot be submitted. A failed load used to leave no dropdown and
  /// no way back — Register just said "select your country" forever — so it
  /// now shows a retry, and [_submit] retries once on its own too.
  Future<void> _loadCountries() async {
    try {
      final countries = await AuthService.instance.countries();
      if (!mounted) return;
      setState(() {
        _countries = countries.map((e) => e as Map).toList();
        _selectedCountryIso ??= _countries.any((c) => c['iso'] == _defaultCountryIso)
            ? _defaultCountryIso
            : (_countries.isNotEmpty ? _countries.first['iso'] as String : null);
      });
    } catch (_) {
      if (mounted) setState(() => _countriesFailed = true);
    } finally {
      if (mounted) setState(() => _isLoadingCountries = false);
    }
  }

  Future<void> _retryCountries() {
    setState(() {
      _isLoadingCountries = true;
      _countriesFailed = false;
    });
    return _loadCountries();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _referralController.dispose();
    super.dispose();
  }

  /// Drops a field's server error as soon as the user edits it, so a fixed
  /// value stops showing the old complaint before the next submit.
  void _clearFieldError(String field) {
    if (!_fieldErrors.containsKey(field)) return;
    setState(() => _fieldErrors = {..._fieldErrors}..remove(field));
  }

  Future<void> _submit() async {
    setState(() => _fieldErrors = {});
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCountryIso == null && !_isLoadingCountries) await _retryCountries();
    if (_selectedCountryIso == null) {
      setState(() => _error = 'Could not load the country list. Check your connection and try again.');
      return;
    }
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      await AuthState.instance.register(
        name: _nameController.text.trim(),
        countryIso: _selectedCountryIso!,
        phone: _phoneController.text.trim(),
        email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
        password: _passwordController.text,
        passwordConfirmation: _confirmController.text,
        referralCode: _referralController.text.trim().isEmpty ? null : _referralController.text.trim().toUpperCase(),
      );
      // The parked deep-link code has now been used (or deliberately
      // cleared) — don't route with it again after sign-in.
      ReferralState.instance.takePendingCode();
      if (mounted) {
        // Registration also signs the user in, so leave the whole auth flow
        // (Register + Login) rather than dropping back onto the login form.
        final nav = Navigator.of(context);
        nav.pop();
        if (nav.canPop()) nav.pop();
      }
    } on ApiException catch (e) {
      final fields = {
        for (final entry in (e.fieldErrors ?? const <String, List<String>>{}).entries)
          if (entry.value.isNotEmpty) entry.key: entry.value.first,
      };
      setState(() {
        _fieldErrors = fields;
        // Every field error already shows under its input; the banner is
        // for anything else (throttling, server errors, no connection).
        _error = fields.keys.any(_shownFields.contains) ? null : e.message;
      });
      _formKey.currentState!.validate();
    } catch (e) {
      setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
      backgroundColor: AppColors.primary,
      body: Column(
        children: [
          _buildHero(context),
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildTabPill(context),
                    const SizedBox(height: 24),
                    _buildForm(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }

  // --- HERO ------------------------------------------------------------
  Widget _buildHero(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Stack(
        children: [
          Positioned(
            top: -60,
            right: -40,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),
          Positioned(
            top: 40,
            right: 60,
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.07),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 26),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const HeroBackButton(),
                const SizedBox(height: 24),
                Text(
                  'Create your\nAlicom account',
                  style: GoogleFonts.interTight(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Join Alicom and start shopping today',
                  style: GoogleFonts.inter(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 14,
                    height: 1.45,
                    letterSpacing: 0.1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- LOGIN / REGISTER TABS -------------------------------------------
  Widget _buildTabPill(BuildContext context) {
    Widget tab(String label, {required bool active, required VoidCallback onTap}) {
      return Expanded(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: active ? AppColors.card : Colors.transparent,
              borderRadius: BorderRadius.circular(999),
              boxShadow: active
                  ? [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 10, offset: const Offset(0, 3))]
                  : null,
            ),
            child: Text(
              label,
              style: TextStyle(
                color: active ? AppColors.inkStrong : AppColors.body,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: AppColors.line.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          tab('Login', active: false, onTap: () => Navigator.of(context).maybePop()),
          tab('Register', active: true, onTap: () {}),
        ],
      ),
    );
  }

  // --- FORM ------------------------------------------------------------
  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _nameController,
            onChanged: (_) => _clearFieldError('name'),
            decoration: const InputDecoration(
              labelText: 'Full name',
              prefixIcon: Icon(Icons.person_outline, size: 20),
            ),
            validator: (value) =>
                (value == null || value.isEmpty) ? 'Enter your name' : _fieldErrors['name'],
          ),
          const SizedBox(height: 14),
          if (_isLoadingCountries)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: LinearProgressIndicator(),
            )
          else if (_countries.isNotEmpty)
            DropdownButtonFormField<String>(
              initialValue: _selectedCountryIso,
              decoration: const InputDecoration(
                labelText: 'Country',
                prefixIcon: Icon(Icons.public, size: 20),
              ),
              items: _countries
                  .map((c) => DropdownMenuItem(
                        value: c['iso'] as String,
                        child: Text('${c['flag'] ?? ''} ${c['name']} (${c['dial_code']})'),
                      ))
                  .toList(),
              onChanged: (value) => setState(() => _selectedCountryIso = value),
              validator: (_) => _fieldErrors['country_iso'],
            )
          else if (_countriesFailed)
            Row(
              children: [
                Icon(Icons.error_outline, size: 18, color: AppColors.sale),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Could not load countries.',
                    style: TextStyle(color: AppColors.body, fontSize: 13),
                  ),
                ),
                TextButton(onPressed: _retryCountries, child: const Text('Retry')),
              ],
            ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _phoneController,
            onChanged: (_) => _clearFieldError('phone'),
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Phone',
              prefixIcon: Icon(Icons.phone_outlined, size: 20),
            ),
            validator: (value) =>
                (value == null || value.isEmpty) ? 'Enter your phone number' : _fieldErrors['phone'],
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _emailController,
            onChanged: (_) => _clearFieldError('email'),
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'E-mail (optional)',
              prefixIcon: Icon(Icons.mail_outline, size: 20),
            ),
            validator: (value) {
              final email = value?.trim() ?? '';
              if (email.isNotEmpty && !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
                return 'Enter a valid e-mail address';
              }
              return _fieldErrors['email'];
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _passwordController,
            onChanged: (_) => _clearFieldError('password'),
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock_outline, size: 20),
              suffixIcon: IconButton(
                icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, size: 20),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            validator: (value) => (value == null || value.length < 8)
                ? 'Password must be at least 8 characters'
                : _fieldErrors['password'],
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _confirmController,
            onChanged: (_) => _clearFieldError('password_confirmation'),
            obscureText: _obscureConfirm,
            decoration: InputDecoration(
              labelText: 'Confirm password',
              prefixIcon: const Icon(Icons.lock_outline, size: 20),
              suffixIcon: IconButton(
                icon: Icon(_obscureConfirm ? Icons.visibility_off : Icons.visibility, size: 20),
                onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) return 'Confirm your password';
              if (value != _passwordController.text) return 'Passwords do not match';
              return _fieldErrors['password_confirmation'];
            },
          ),
          const SizedBox(height: 14),
          // Optional. A 422 on referral_code creates no account, so the user
          // can fix or clear the code and submit again.
          ReferralCodeField(
            controller: _referralController,
            serverError: _fieldErrors['referral_code'],
            onEdited: () => _clearFieldError('referral_code'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 14),
            AuthErrorBanner(message: _error!),
          ],
          const SizedBox(height: 22),
          ElevatedButton(
            onPressed: _isSubmitting ? null : _submit,
            child: _isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Register'),
          ),
          const SizedBox(height: 16),
          Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).maybePop(),
              child: Text.rich(
                TextSpan(
                  text: 'Already have an account? ',
                  style: TextStyle(color: AppColors.body, fontSize: 13.5),
                  children: [
                    TextSpan(
                      text: 'Login',
                      style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
