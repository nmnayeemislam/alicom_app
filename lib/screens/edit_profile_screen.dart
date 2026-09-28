import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../core/api_config.dart';
import '../core/api_exception.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../state/auth_state.dart';
import '../theme/app_theme.dart';
import '../widgets/app_loader.dart';
import '../widgets/auth_header.dart';

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
    final user = AuthState.instance.user;
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Who is being edited — the form alone gave no sense of it.
                _Header(user: user),
                const SizedBox(height: 20),
                _FieldGroup(
                  title: 'Your details',
                  icon: Icons.person_outline_rounded,
                  children: [
                    TextFormField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Full name',
                        prefixIcon: Icon(Icons.badge_outlined, size: 20),
                      ),
                      validator: (value) => (value == null || value.isEmpty) ? 'Enter your name' : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email (optional)',
                        prefixIcon: Icon(Icons.mail_outline, size: 20),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _FieldGroup(
                  title: 'Contact & delivery',
                  icon: Icons.local_shipping_outlined,
                  children: [
                    if (_isLoadingCountries)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Center(child: AppLoader(size: 52)),
                      )
                    else if (_countries.isNotEmpty)
                      DropdownButtonFormField<String>(
                        initialValue: _selectedCountryIso,
                        isExpanded: true,
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
                      validator: (value) => (value == null || value.isEmpty) ? 'Enter your phone number' : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _addressController,
                      maxLines: 2,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Address (optional)',
                        // Aligned to the first line, not the middle of a
                        // two-line box.
                        prefixIcon: Padding(
                          padding: EdgeInsets.only(bottom: 22),
                          child: Icon(Icons.location_on_outlined, size: 20),
                        ),
                      ),
                    ),
                  ],
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  AuthErrorBanner(message: _error!),
                ],
                const SizedBox(height: 22),
                ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  child: _isSubmitting
                      ? const AppLoader.onAccent(size: 46)
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

/// Avatar, name and e-mail of the account being edited.
class _Header extends StatelessWidget {
  final AppUser? user;
  const _Header({required this.user});

  @override
  Widget build(BuildContext context) {
    final name = (user?.name ?? '').trim();
    final initial = name.isEmpty ? '?' : name.characters.first.toUpperCase();
    final photo = ApiConfig.resolveUrl(user?.avatarUrl);

    return Row(
      children: [
        Container(
          width: 62,
          height: 62,
          decoration: BoxDecoration(
            color: AppColors.accentSoft,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.primary, width: 2),
          ),
          clipBehavior: Clip.antiAlias,
          child: photo != null && photo.isNotEmpty
              ? CachedNetworkImage(imageUrl: photo, fit: BoxFit.cover)
              : Center(
                  child: Text(
                    initial,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name.isEmpty ? 'Your profile' : name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                  color: AppColors.inkStrong,
                ),
              ),
              if ((user?.email ?? '').isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  user!.email!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: AppColors.muted),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// A titled card of related fields, so the form reads as two short groups
/// rather than one long column of boxes.
class _FieldGroup extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _FieldGroup({required this.title, required this.icon, required this.children});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 16, offset: const Offset(0, 6)),
        ],
      ),
      child: Material(
        color: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppColors.line),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: AppColors.accentSoft,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(icon, size: 18, color: AppColors.primary),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                      color: AppColors.inkStrong,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}
