import 'package:flutter/material.dart';

import '../core/api_exception.dart';
import '../services/auth_service.dart';
import '../state/auth_state.dart';

/// Mirrors UpdateProfileRequest: name/country_iso/phone are required,
/// email/address optional. Pre-fills from the currently signed-in user.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(text: AuthState.instance.user?.name);
  late final _emailController = TextEditingController(text: AuthState.instance.user?.email);
  late final _phoneController = TextEditingController(text: AuthState.instance.user?.phone);
  late final _addressController = TextEditingController(text: AuthState.instance.user?.address);

  bool _isSubmitting = false;
  String? _error;

  bool _isLoadingCountries = true;
  List<Map> _countries = [];
  String? _selectedCountryIso;

  @override
  void initState() {
    super.initState();
    _selectedCountryIso = AuthState.instance.user?.countryIso;
    _loadCountries();
  }

  Future<void> _loadCountries() async {
    try {
      final countries = await AuthService.instance.countries();
      setState(() {
        _countries = countries.map((e) => e as Map).toList();
        _selectedCountryIso ??= _countries.isNotEmpty ? _countries.first['iso'] as String : null;
      });
    } catch (_) {
      // Fall back to whatever country the profile already had.
    } finally {
      if (mounted) setState(() => _isLoadingCountries = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
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
      await AuthState.instance.updateProfile(
        name: _nameController.text.trim(),
        countryIso: _selectedCountryIso!,
        phone: _phoneController.text.trim(),
        email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
        address: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated')),
        );
        Navigator.of(context).pop();
      }
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Could not update your profile. Please try again.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Full name'),
                  validator: (value) => (value == null || value.isEmpty) ? 'Enter your name' : null,
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
                    decoration: const InputDecoration(labelText: 'Country'),
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
                  decoration: const InputDecoration(labelText: 'Phone'),
                  validator: (value) => (value == null || value.isEmpty) ? 'Enter your phone number' : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email (optional)'),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _addressController,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Address (optional)'),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                ],
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Save Changes'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
