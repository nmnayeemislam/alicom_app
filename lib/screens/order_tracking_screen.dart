import 'package:flutter/material.dart';

import '../core/api_exception.dart';
import '../services/commerce_service.dart';
import '../theme/app_theme.dart';

/// Guest-accessible order tracking (order code + phone, no sign-in) — mirrors
/// pages/tracking.vue and OrderTrackingController's phone-gated lookup.
class OrderTrackingScreen extends StatefulWidget {
  const OrderTrackingScreen({super.key});

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _orderCodeController = TextEditingController();
  final _phoneController = TextEditingController();

  bool _isSubmitting = false;
  String? _error;
  Map? _result;

  @override
  void dispose() {
    _orderCodeController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _track() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSubmitting = true;
      _error = null;
      _result = null;
    });
    try {
      final response = await CommerceService.instance.trackOrder(
        orderCode: _orderCodeController.text.trim(),
        phone: _phoneController.text.trim(),
      );
      final data = (response is Map ? response['data'] ?? response : {}) as Map;
      setState(() => _result = data);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Could not find that order.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Track Order')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _orderCodeController,
                  decoration: const InputDecoration(labelText: 'Order code'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Phone number used to order'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 18),
                ElevatedButton(
                  onPressed: _isSubmitting ? null : _track,
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Track'),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                ],
                if (_result != null) ...[
                  const SizedBox(height: 24),
                  Text('Status: ${_result!['current_status']}', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  ...((_result!['status_flow'] as List?) ?? []).map((raw) {
                    final step = raw as Map;
                    final state = step['state'] as String? ?? 'upcoming';
                    final isCompleted = state == 'completed' || state == 'current';
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
                        color: isCompleted ? AppColors.accent : AppColors.muted,
                      ),
                      title: Text(step['status'] as String? ?? ''),
                      subtitle: step['changed_at'] != null ? Text(step['changed_at'] as String) : null,
                    );
                  }),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
