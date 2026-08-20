import 'package:flutter/material.dart';

import '../core/api_exception.dart';
import '../services/auth_service.dart';

enum _Step { requestOtp, verifyOtp, resetPassword, done }

/// Three-step flow mirroring AuthController: forgotPassword (send OTP by
/// phone or email) → verifyOtp (exchanges the OTP for a short-lived
/// reset_token) → resetPassword (consumes that token with a new password).
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  _Step _step = _Step.requestOtp;
  final _identifierController = TextEditingController();
  final _otpController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isSubmitting = false;
  String? _error;
  String? _resetToken;

  bool get _identifierIsEmail => _identifierController.text.contains('@');

  @override
  void dispose() {
    _identifierController.dispose();
    _otpController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    final identifier = _identifierController.text.trim();
    if (identifier.isEmpty) return;

    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      await AuthService.instance.forgotPassword(
        email: _identifierIsEmail ? identifier : null,
        phone: _identifierIsEmail ? null : identifier,
      );
      setState(() => _step = _Step.verifyOtp);
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
    if (otp.isEmpty) return;

    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      final identifier = _identifierController.text.trim();
      final token = await AuthService.instance.verifyOtp(
        email: _identifierIsEmail ? identifier : null,
        phone: _identifierIsEmail ? null : identifier,
        otp: otp,
      );
      setState(() {
        _resetToken = token;
        _step = _Step.resetPassword;
      });
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Invalid or expired code.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _resetPassword() async {
    final password = _passwordController.text;
    if (password.length < 8) {
      setState(() => _error = 'Password must be at least 8 characters');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      final identifier = _identifierController.text.trim();
      await AuthService.instance.resetPassword(
        email: _identifierIsEmail ? identifier : null,
        phone: _identifierIsEmail ? null : identifier,
        resetToken: _resetToken!,
        password: password,
      );
      setState(() => _step = _Step.done);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Could not reset your password. Please try again.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reset Password')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_step == _Step.requestOtp) ...[
                const Text('Enter your email or phone to receive a reset code.'),
                const SizedBox(height: 16),
                TextField(
                  controller: _identifierController,
                  decoration: const InputDecoration(labelText: 'Email or phone'),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _isSubmitting ? null : _sendOtp,
                  child: _submitLabel('Send Code'),
                ),
              ] else if (_step == _Step.verifyOtp) ...[
                Text('Enter the code sent to ${_identifierController.text}.'),
                const SizedBox(height: 16),
                TextField(
                  controller: _otpController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Verification code'),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _isSubmitting ? null : _verifyOtp,
                  child: _submitLabel('Verify'),
                ),
                TextButton(
                  onPressed: _isSubmitting ? null : _sendOtp,
                  child: const Text('Resend code'),
                ),
              ] else if (_step == _Step.resetPassword) ...[
                const Text('Choose a new password.'),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'New password'),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _isSubmitting ? null : _resetPassword,
                  child: _submitLabel('Reset Password'),
                ),
              ] else ...[
                const Icon(Icons.check_circle, size: 48, color: Colors.green),
                const SizedBox(height: 12),
                const Text('Your password has been reset. Please sign in.'),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Back to Sign In'),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 14),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _submitLabel(String label) {
    return _isSubmitting
        ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
          )
        : Text(label);
  }
}
