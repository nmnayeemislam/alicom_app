import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/api_exception.dart';
import '../services/auth_service.dart';
import '../state/auth_state.dart';
import '../theme/app_theme.dart';
import '../widgets/auth_header.dart';

/// Matches the login screen's layout: primary-color hero + rounded sheet
/// with a Login/Register tab pill (Register active here; Login pops back).
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSubmitting = false;
  String? _error;
  bool _obscurePassword = true;

  bool _isLoadingCountries = true;
  List<Map> _countries = [];
  String? _selectedCountryIso;

  @override
  void initState() {
    super.initState();
    _loadCountries();
  }

  Future<void> _loadCountries() async {
    try {
      final countries = await AuthService.instance.countries();
      setState(() {
        _countries = countries.map((e) => e as Map).toList();
        _selectedCountryIso = _countries.isNotEmpty ? _countries.first['iso'] as String : null;
      });
    } catch (_) {
      // Fall back to a manual entry if the list can't be loaded.
    } finally {
      if (mounted) setState(() => _isLoadingCountries = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCountryIso == null) {
      setState(() => _error = 'Please select your country.');
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
      );
      if (mounted) {
        // Registration also signs the user in, so leave the whole auth flow
        // (Register + Login) rather than dropping back onto the login form.
        final nav = Navigator.of(context);
        nav.pop();
        if (nav.canPop()) nav.pop();
      }
    } on ApiException catch (e) {
      setState(() => _error = e.message);
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
            decoration: const InputDecoration(
              labelText: 'Full name',
              prefixIcon: Icon(Icons.person_outline, size: 20),
            ),
            validator: (value) =>
                (value == null || value.isEmpty) ? 'Enter your name' : null,
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
            ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Phone',
              prefixIcon: Icon(Icons.phone_outlined, size: 20),
            ),
            validator: (value) =>
                (value == null || value.isEmpty) ? 'Enter your phone number' : null,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'E-mail (optional)',
              prefixIcon: Icon(Icons.mail_outline, size: 20),
            ),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _passwordController,
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
                : null,
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
