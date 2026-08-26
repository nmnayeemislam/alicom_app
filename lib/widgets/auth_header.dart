import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Circular back button for the teal hero headers. Renders nothing when
/// there is no route to pop, and uses a solid white chip with a generous
/// hit area so the tap always lands.
class HeroBackButton extends StatelessWidget {
  const HeroBackButton({super.key});

  @override
  Widget build(BuildContext context) {
    if (!Navigator.of(context).canPop()) return const SizedBox(height: 44);
    return Align(
      alignment: Alignment.centerLeft,
      child: Material(
        color: Colors.white,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: () => Navigator.of(context).pop(),
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(Icons.arrow_back, color: AppColors.primary, size: 22),
          ),
        ),
      ),
    );
  }
}

/// Shared header for the auth screens: the Alicom logo on a white plate
/// (the JPEG has a light background, so the plate keeps it clean in dark
/// mode too), followed by a title and supporting line.
class AuthHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const AuthHeader({super.key, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.line),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 16, offset: const Offset(0, 6)),
            ],
          ),
          child: Image.asset('assets/images/app_logo.jpeg', height: 44, fit: BoxFit.contain),
        ),
        const SizedBox(height: 24),
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.inkStrong),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: AppColors.body, height: 1.4),
        ),
      ],
    );
  }
}

/// Inline error banner used across the auth forms.
class AuthErrorBanner extends StatelessWidget {
  final String message;

  const AuthErrorBanner({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.sale.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.sale.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 18, color: AppColors.sale),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message, style: TextStyle(color: AppColors.sale, fontSize: 13, height: 1.35)),
          ),
        ],
      ),
    );
  }
}
