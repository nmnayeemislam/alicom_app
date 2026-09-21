import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/api_exception.dart';
import '../state/auth_state.dart';
import '../theme/app_theme.dart';
import '../widgets/auth_header.dart';
import 'forgot_password_screen.dart';
import 'register_screen.dart';

enum _LoginMode { password, otp }

/// Dark hero header + rounded sheet layout. The sheet holds a Login/Register
/// tab pill (Register pushes [RegisterScreen]) and the sign-in form; phone
/// OTP stays reachable through a text link below the submit button.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  // Demo customer on the UAT backend, pre-filled in debug builds only so
  // testers can sign in with one tap. Never shipped in release.
  static const _demoEmail = 'demo@alicom.com';
  static const _demoPassword = 'demo1234';

  final _emailController =
      TextEditingController(text: kDebugMode ? _demoEmail : null);
  final _passwordController =
      TextEditingController(text: kDebugMode ? _demoPassword : null);
  final _otpPhoneController = TextEditingController();
  final _otpController = TextEditingController();

  _LoginMode _mode = _LoginMode.password;
  bool _otpSent = false;
  bool _isSubmitting = false;
  String? _error;
  bool _obscurePassword = true;
  bool _rememberMe = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _otpPhoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _submitPassword() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      await AuthState.instance.login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _sendOtp() async {
    final phone = _otpPhoneController.text.trim();
    if (phone.isEmpty) {
      setState(() => _error = 'Enter your phone number.');
      return;
    }
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      await AuthState.instance.sendLoginOtp(phone: phone);
      if (mounted) setState(() => _otpSent = true);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Could not send the code. Please try again.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _verifyOtp() async {
    final otp = _otpController.text.trim();
    if (otp.isEmpty) {
      setState(() => _error = 'Enter the code we sent you.');
      return;
    }
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      await AuthState.instance.loginWithOtp(
        phone: _otpPhoneController.text.trim(),
        otp: otp,
      );
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Invalid or expired code. Please try again.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _switchMode(_LoginMode mode) {
    setState(() {
      _mode = mode;
      _otpSent = false;
      _error = null;
    });
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
                    if (_mode == _LoginMode.password) _buildPasswordForm() else _buildOtpForm(),
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

  // --- DARK HERO -------------------------------------------------------
  Widget _buildHero(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Stack(
        children: [
          // Soft decorative circles, echoing the mock's background shapes.
          Positioned(
            top: -60,
            right: -40,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.04),
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
                color: Colors.white.withValues(alpha: 0.05),
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
                  'Go ahead and set up\nyour account',
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
                  'Sign in to enjoy the best shopping experience',
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
          tab('Login', active: true, onTap: () {}),
          tab(
            'Register',
            active: false,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const RegisterScreen()),
            ),
          ),
        ],
      ),
    );
  }

  // --- PASSWORD FORM ---------------------------------------------------
  Widget _buildPasswordForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildDemoCard(),
          const SizedBox(height: 14),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            decoration: const InputDecoration(
              labelText: 'E-mail ID',
              prefixIcon: Icon(Icons.mail_outline, size: 20),
            ),
            validator: (value) => (value == null || value.isEmpty) ? 'Enter your email' : null,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            autofillHints: const [AutofillHints.password],
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock_outline, size: 20),
              suffixIcon: IconButton(
                icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, size: 20),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            validator: (value) => (value == null || value.isEmpty) ? 'Enter your password' : null,
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              SizedBox(
                width: 22,
                height: 22,
                child: Checkbox(
                  value: _rememberMe,
                  onChanged: (v) => setState(() => _rememberMe = v ?? true),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                ),
              ),
              const SizedBox(width: 8),
              Text('Remember me', style: TextStyle(fontSize: 13, color: AppColors.bodyStrong)),
              const Spacer(),
              InkWell(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
                ),
                child: Text(
                  'Forgot Password?',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary),
                ),
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 14),
            AuthErrorBanner(message: _error!),
          ],
          const SizedBox(height: 22),
          ElevatedButton(
            onPressed: _isSubmitting ? null : _submitPassword,
            child: _isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Login'),
          ),
          const SizedBox(height: 16),
          Center(
            child: TextButton(
              onPressed: () => _switchMode(_LoginMode.otp),
              child: Text(
                'Sign in with phone OTP instead',
                style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 13.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- DEMO ACCOUNT ----------------------------------------------------
  /// Shows the shared UAT demo credentials so testers can sign in without
  /// registering; tapping fills the form.
  Widget _buildDemoCard() {
    return InkWell(
      onTap: () => setState(() {
        _emailController.text = _demoEmail;
        _passwordController.text = _demoPassword;
        _error = null;
      }),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.science_outlined, size: 18, color: AppColors.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Demo account',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Email: $_demoEmail\nPassword: $_demoPassword',
                    style: TextStyle(color: AppColors.bodyStrong, fontSize: 12.5, height: 1.4),
                  ),
                ],
              ),
            ),
            Text(
              'Use',
              style: TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }

  // --- OTP FORM --------------------------------------------------------
  Widget _buildOtpForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: _otpPhoneController,
          keyboardType: TextInputType.phone,
          enabled: !_otpSent,
          decoration: const InputDecoration(
            labelText: 'Phone number',
            prefixIcon: Icon(Icons.phone_outlined, size: 20),
          ),
        ),
        if (_otpSent) ...[
          const SizedBox(height: 14),
          TextFormField(
            controller: _otpController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Verification code',
              prefixIcon: Icon(Icons.pin_outlined, size: 20),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _isSubmitting ? null : _sendOtp,
              child: const Text('Resend code'),
            ),
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 14),
          AuthErrorBanner(message: _error!),
        ],
        const SizedBox(height: 22),
        ElevatedButton(
          onPressed: _isSubmitting ? null : (_otpSent ? _verifyOtp : _sendOtp),
          child: _isSubmitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Text(_otpSent ? 'Verify & Login' : 'Send Code'),
        ),
        const SizedBox(height: 16),
        Center(
          child: TextButton(
            onPressed: () => _switchMode(_LoginMode.password),
            child: Text(
              'Use e-mail & password instead',
              style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 13.5),
            ),
          ),
        ),
      ],
    );
  }
}
