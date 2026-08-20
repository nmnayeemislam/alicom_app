import 'package:flutter/material.dart';

import '../core/api_exception.dart';
import '../services/address_service.dart';

/// Add/edit form for AddressController's fields: address_line, phone, city,
/// post_code, label, recipient, note, is_default.
class AddressFormScreen extends StatefulWidget {
  final Map? existing;

  const AddressFormScreen({super.key, this.existing});

  @override
  State<AddressFormScreen> createState() => _AddressFormScreenState();
}

class _AddressFormScreenState extends State<AddressFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _labelController = TextEditingController(text: widget.existing?['label'] as String?);
  late final _recipientController = TextEditingController(text: widget.existing?['recipient'] as String?);
  late final _phoneController = TextEditingController(text: widget.existing?['phone'] as String?);
  late final _addressLineController = TextEditingController(text: widget.existing?['address_line'] as String?);
  late final _cityController = TextEditingController(text: widget.existing?['city'] as String?);
  late final _postCodeController = TextEditingController(text: widget.existing?['post_code'] as String?);
  late final _noteController = TextEditingController(text: widget.existing?['note'] as String?);
  late bool _isDefault = widget.existing?['is_default'] == true;

  bool _isSubmitting = false;
  String? _error;

  bool get _isEditing => widget.existing != null;

  @override
  void dispose() {
    _labelController.dispose();
    _recipientController.dispose();
    _phoneController.dispose();
    _addressLineController.dispose();
    _cityController.dispose();
    _postCodeController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    final payload = {
      'label': _labelController.text.trim(),
      'recipient': _recipientController.text.trim(),
      'phone': _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
      'address_line': _addressLineController.text.trim(),
      'city': _cityController.text.trim(),
      'post_code': _postCodeController.text.trim(),
      'note': _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
      'is_default': _isDefault,
    };

    try {
      if (_isEditing) {
        await AddressService.instance.update(widget.existing!['id'] as int, payload);
      } else {
        await AddressService.instance.store(payload);
      }
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Could not save this address.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit Address' : 'Add Address')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _labelController,
                  decoration: const InputDecoration(labelText: 'Label (e.g. Home, Office)'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _recipientController,
                  decoration: const InputDecoration(labelText: 'Recipient name'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Phone (optional)'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _addressLineController,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Address line'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _cityController,
                  decoration: const InputDecoration(labelText: 'City'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _postCodeController,
                  decoration: const InputDecoration(labelText: 'Post code'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _noteController,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Note (optional)'),
                ),
                SwitchListTile(
                  value: _isDefault,
                  onChanged: (v) => setState(() => _isDefault = v),
                  title: const Text('Set as default address'),
                  contentPadding: EdgeInsets.zero,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 10),
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
                      : Text(_isEditing ? 'Save Changes' : 'Add Address'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
