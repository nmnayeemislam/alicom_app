import 'dart:io';

import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';

/// Reads the downloaded invoice inside the app.
///
/// Rendered with `pdfx` rather than handing the file to another app: many
/// phones have no PDF reader installed, and `syncfusion_flutter_pdfviewer`
/// carries a commercial licence that is not ours to accept on the shop's
/// behalf. pdfx is MIT and draws through the platform's own renderer
/// (Android `PdfRenderer`, iOS PDFKit), so there is nothing extra to ship.
class InvoiceViewerScreen extends StatefulWidget {
  final File file;
  final String? orderCode;

  const InvoiceViewerScreen({super.key, required this.file, this.orderCode});

  @override
  State<InvoiceViewerScreen> createState() => _InvoiceViewerScreenState();
}

class _InvoiceViewerScreenState extends State<InvoiceViewerScreen> {
  late final PdfControllerPinch _controller = PdfControllerPinch(
    document: PdfDocument.openFile(widget.file.path),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _share() async {
    final l10n = AppLocalizations.of(context);
    final box = context.findRenderObject() as RenderBox?;
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(widget.file.path, mimeType: 'application/pdf')],
        text: l10n.invoiceShareText(widget.orderCode ?? ''),
        // Anchor for the iPad share popover.
        sharePositionOrigin: box == null ? null : box.localToGlobal(Offset.zero) & box.size,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.orderCode ?? l10n.invoice),
        actions: [
          IconButton(
            tooltip: l10n.share,
            onPressed: _share,
            icon: const Icon(Icons.ios_share_rounded),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: PdfViewPinch(
        controller: _controller,
        builders: PdfViewPinchBuilders<DefaultBuilderOptions>(
          options: const DefaultBuilderOptions(),
          documentLoaderBuilder: (_) => const Center(
            child: SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 2)),
          ),
          pageLoaderBuilder: (_) => const Center(
            child: SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 2)),
          ),
          errorBuilder: (_, error) => Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                '$error',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.muted),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
