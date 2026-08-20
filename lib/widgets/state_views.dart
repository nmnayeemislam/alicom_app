import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Shared loading/error/empty placeholders so every screen's "in-between"
/// states look and read the same way, instead of each screen inventing its
/// own spinner/error text.
class LoadingView extends StatelessWidget {
  const LoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: CircularProgressIndicator(color: AppColors.accent),
    );
  }
}

class ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const ErrorView({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      children: [
        const SizedBox(height: 96),
        Icon(Icons.wifi_off_rounded, size: 44, color: AppColors.muted),
        const SizedBox(height: 14),
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.muted),
        ),
        if (onRetry != null) ...[
          const SizedBox(height: 18),
          Center(
            child: OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
          ),
        ],
      ],
    );
  }
}

class EmptyView extends StatelessWidget {
  final IconData icon;
  final String message;
  final Widget? action;

  const EmptyView({
    super.key,
    this.icon = Icons.inbox_outlined,
    required this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      children: [
        const SizedBox(height: 96),
        Icon(icon, size: 44, color: AppColors.muted),
        const SizedBox(height: 14),
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.muted),
        ),
        if (action != null) ...[
          const SizedBox(height: 18),
          Center(child: action!),
        ],
      ],
    );
  }
}
