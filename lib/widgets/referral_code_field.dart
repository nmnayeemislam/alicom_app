import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/referral.dart';
import '../screens/qr_scan_screen.dart';
import '../services/referral_service.dart';
import '../theme/app_theme.dart';

/// Referral code input used at sign-up and on the "apply a code" screen.
///
/// - A QR icon opens the scanner; a scanned `…/ref/{CODE}` link fills in
///   just the code.
/// - When the field loses focus (debounced) the code is checked against
///   the public `POST /referral/validate`: green "Invited by {name}" when
///   valid, a red hint when not. The hint never blocks typing or submit —
///   the server has the final say.
/// - [serverError] (a 422 on `referral_code`) shows under the field and
///   clears as soon as the user edits.
class ReferralCodeField extends StatefulWidget {
  final TextEditingController controller;
  final String? serverError;
  final VoidCallback? onEdited;
  final String? label;
  final bool autofocus;

  const ReferralCodeField({
    super.key,
    required this.controller,
    this.serverError,
    this.onEdited,
    this.label,
    this.autofocus = false,
  });

  @override
  State<ReferralCodeField> createState() => _ReferralCodeFieldState();
}

class _ReferralCodeFieldState extends State<ReferralCodeField> {
  final _focusNode = FocusNode();
  Timer? _debounce;

  /// The code the current hint is about, so a stale response (the user kept
  /// typing) is dropped.
  String? _checkedCode;
  ReferralCodeCheck? _check;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) _scheduleCheck();
    });
    // Pre-filled (deep link / scan) — check it straight away.
    if (widget.controller.text.trim().isNotEmpty) _scheduleCheck(immediate: true);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _focusNode.dispose();
    super.dispose();
  }

  void _scheduleCheck({bool immediate = false}) {
    _debounce?.cancel();
    _debounce = Timer(immediate ? Duration.zero : const Duration(milliseconds: 350), _runCheck);
  }

  Future<void> _runCheck() async {
    final code = widget.controller.text.trim().toUpperCase();
    if (code.isEmpty) {
      setState(() {
        _check = null;
        _checkedCode = null;
      });
      return;
    }
    if (code == _checkedCode && _check != null) return;
    setState(() {
      _checking = true;
      _checkedCode = code;
    });
    try {
      final result = await ReferralService.instance.validate(code);
      if (!mounted || _checkedCode != code) return;
      setState(() => _check = result);
    } catch (_) {
      // Offline / throttled: no hint; submitting still validates server-side.
      if (mounted && _checkedCode == code) setState(() => _check = null);
    } finally {
      if (mounted && _checkedCode == code) setState(() => _checking = false);
    }
  }

  Future<void> _scan() async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const QrScanScreen()),
    );
    if (code == null || !mounted) return;
    widget.controller.text = code;
    widget.onEdited?.call();
    _scheduleCheck(immediate: true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final code = widget.controller.text.trim().toUpperCase();
    final check = code.isNotEmpty && code == _checkedCode ? _check : null;

    // Server 422 wins; otherwise the live hint.
    String? errorText = widget.serverError;
    String? helperText;
    if (errorText == null && check != null && !_checking) {
      if (check.valid && check.eligible == false) {
        // Signed in: a real code this account can't use (its own, already
        // referred, existing customer…) — the server says why.
        errorText = check.message.isNotEmpty ? check.message : l10n.codeNotValid;
      } else if (check.valid) {
        helperText = check.referrerName != null ? l10n.codeInvitedBy(check.referrerName!) : null;
      } else {
        errorText = l10n.codeNotValid;
      }
    }

    return TextFormField(
      controller: widget.controller,
      focusNode: _focusNode,
      autofocus: widget.autofocus,
      textCapitalization: TextCapitalization.characters,
      onChanged: (_) {
        if (_check != null || _checkedCode != null) {
          setState(() {
            _check = null;
            _checkedCode = null;
          });
        }
        widget.onEdited?.call();
      },
      decoration: InputDecoration(
        labelText: widget.label ?? l10n.referralCodeField,
        prefixIcon: const Icon(Icons.card_giftcard_rounded, size: 20),
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_checking)
              const Padding(
                padding: EdgeInsets.only(right: 4),
                child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
              ),
            IconButton(
              tooltip: l10n.scanQr,
              icon: const Icon(Icons.qr_code_scanner_rounded, size: 22),
              onPressed: _scan,
            ),
          ],
        ),
        errorText: errorText,
        errorMaxLines: 2,
        helperText: helperText,
        helperStyle: TextStyle(color: const Color(0xFF1FA65A), fontWeight: FontWeight.w600, fontSize: 12.5),
        helperMaxLines: 2,
        focusedBorder: helperText != null
            ? OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFF1FA65A), width: 1.5),
              )
            : null,
        enabledBorder: helperText != null
            ? OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: const Color(0xFF1FA65A).withValues(alpha: 0.7)),
              )
            : null,
        hintStyle: TextStyle(color: AppColors.muted),
      ),
    );
  }
}
