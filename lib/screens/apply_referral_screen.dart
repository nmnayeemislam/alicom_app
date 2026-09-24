import 'package:flutter/material.dart';

import '../core/api_exception.dart';
import '../l10n/app_localizations.dart';
import '../services/referral_service.dart';
import '../state/referral_state.dart';
import '../theme/app_theme.dart';
import '../widgets/referral_code_field.dart';
import '../widgets/referral_widgets.dart';

/// "Have a referral code?" — attach a friend's code after sign-up. Only
/// offered while `GET /referral` says `can_apply_code` (a new customer with
/// no orders and no referrer yet). Pops `true` once applied.
class ApplyReferralScreen extends StatefulWidget {
  final String? initialCode;

  const ApplyReferralScreen({super.key, this.initialCode});

  @override
  State<ApplyReferralScreen> createState() => _ApplyReferralScreenState();
}

class _ApplyReferralScreenState extends State<ApplyReferralScreen> {
  late final _controller = TextEditingController(text: widget.initialCode ?? '');
  bool _submitting = false;
  String? _fieldError;
  String? _bannerError;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _apply() async {
    final l10n = AppLocalizations.of(context);
    final code = _controller.text.trim().toUpperCase();
    if (code.isEmpty) {
      setState(() => _fieldError = l10n.enterReferralCode);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _submitting = true;
      _fieldError = null;
      _bannerError = null;
    });
    try {
      final name = await ReferralService.instance.apply(code);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.codeApplied(name ?? ''))),
      );
      ReferralState.instance.refresh();
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      final fieldMessage = e.fieldErrors?['referral_code']?.firstOrNull;
      setState(() {
        if (fieldMessage != null) {
          _fieldError = fieldMessage;
        } else {
          _bannerError = referralErrorMessage(context, e);
        }
      });
    } catch (e) {
      if (mounted) setState(() => _bannerError = referralErrorMessage(context, e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(l10n.applyCodeTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          Icon(Icons.card_giftcard_rounded, size: 56, color: AppColors.primary),
          const SizedBox(height: 14),
          Text(
            l10n.applyCodeBody,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14.5, height: 1.4, color: AppColors.body),
          ),
          const SizedBox(height: 24),
          ReferralCodeField(
            controller: _controller,
            label: l10n.enterReferralCode,
            serverError: _fieldError,
            autofocus: widget.initialCode == null,
            onEdited: () {
              if (_fieldError != null) setState(() => _fieldError = null);
            },
          ),
          if (_bannerError != null) ...[
            const SizedBox(height: 12),
            Text(_bannerError!, style: TextStyle(color: AppColors.sale, fontSize: 13)),
          ],
          const SizedBox(height: 22),
          ElevatedButton(
            onPressed: _submitting ? null : _apply,
            style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
            child: _submitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Text(l10n.apply),
          ),
        ],
      ),
    );
  }
}
