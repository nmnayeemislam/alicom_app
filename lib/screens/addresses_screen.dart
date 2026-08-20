import 'package:flutter/material.dart';

import '../services/address_service.dart';
import '../theme/app_theme.dart';
import '../widgets/state_views.dart';
import 'address_form_screen.dart';

class AddressesScreen extends StatefulWidget {
  const AddressesScreen({super.key});

  @override
  State<AddressesScreen> createState() => _AddressesScreenState();
}

class _AddressesScreenState extends State<AddressesScreen> {
  bool _isLoading = true;
  String? _error;
  List<Map> _addresses = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final response = await AddressService.instance.index();
      final data = (response is Map ? response['data'] ?? response : {}) as Map;
      _addresses = ((data['addresses'] as List?) ?? [])
          .map((e) => e as Map)
          .toList();
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _openForm({Map? existing}) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => AddressFormScreen(existing: existing)),
    );
    if (saved == true) _load();
  }

  Future<void> _delete(int id) async {
    try {
      await AddressService.instance.destroy(id);
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not delete address: $e')),
        );
      }
    }
  }

  Future<void> _setDefault(int id) async {
    try {
      await AddressService.instance.setDefault(id);
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not set default address: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Addresses')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(),
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _isLoading
            ? const LoadingView()
            : _error != null
            ? ErrorView(message: _error!, onRetry: _load)
            : _addresses.isEmpty
            ? const EmptyView(
                icon: Icons.location_on_outlined,
                message: 'No saved addresses yet.',
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: _addresses.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final address = _addresses[index];
                  final isDefault = address['is_default'] == true;

                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isDefault ? AppColors.accent : AppColors.line,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              address['label'] as String? ?? '',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            if (isDefault) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.accentSoft,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  'Default',
                                  style: TextStyle(fontSize: 10, color: AppColors.accentDark),
                                ),
                              ),
                            ],
                            const Spacer(),
                            PopupMenuButton<String>(
                              onSelected: (value) {
                                final id = address['id'] as int;
                                switch (value) {
                                  case 'edit':
                                    _openForm(existing: address);
                                    break;
                                  case 'default':
                                    _setDefault(id);
                                    break;
                                  case 'delete':
                                    _delete(id);
                                    break;
                                }
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(value: 'edit', child: Text('Edit')),
                                if (!isDefault)
                                  const PopupMenuItem(value: 'default', child: Text('Set as default')),
                                const PopupMenuItem(value: 'delete', child: Text('Delete')),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(address['recipient'] as String? ?? ''),
                        if ((address['phone'] as String?)?.isNotEmpty == true)
                          Text(address['phone'] as String, style: TextStyle(color: AppColors.muted)),
                        Text(
                          '${address['address_line'] ?? ''}, ${address['city'] ?? ''} ${address['post_code'] ?? ''}',
                          style: TextStyle(color: AppColors.muted),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}
