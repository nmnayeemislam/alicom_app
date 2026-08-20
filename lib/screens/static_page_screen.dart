import 'package:flutter/material.dart';

import '../services/content_service.dart';
import '../theme/app_theme.dart';
import '../widgets/simple_html.dart';
import '../widgets/state_views.dart';

/// Renders a CMS static page fetched from `/pages/{slug}` — used for About
/// Us, Privacy Policy, Terms & Conditions, and similar footer/legal pages.
/// Mirrors PageController@show / PageResource.
class StaticPageScreen extends StatefulWidget {
  final String slug;
  final String fallbackTitle;

  const StaticPageScreen({super.key, required this.slug, required this.fallbackTitle});

  @override
  State<StaticPageScreen> createState() => _StaticPageScreenState();
}

class _StaticPageScreenState extends State<StaticPageScreen> {
  bool _isLoading = true;
  String? _error;
  Map? _page;

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
      final response = await ContentService.instance.page(widget.slug);
      final data = (response is Map ? response['data'] ?? response : response) as Map?;
      _page = data;
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = (_page?['title'] as String?) ?? widget.fallbackTitle;

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: _isLoading
          ? const LoadingView()
          : _error != null
          ? ErrorView(message: _error!, onRetry: _load)
          : _page == null
          ? const EmptyView(icon: Icons.description_outlined, message: 'Page not found.')
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  if ((_page?['hero_title'] as String?)?.isNotEmpty == true) ...[
                    Text(
                      _page!['hero_title'] as String,
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.inkStrong),
                    ),
                    const SizedBox(height: 8),
                  ],
                  if ((_page?['hero_description'] as String?)?.isNotEmpty == true) ...[
                    Text(
                      _page!['hero_description'] as String,
                      style: TextStyle(color: AppColors.body, fontSize: 14, height: 1.5),
                    ),
                    const SizedBox(height: 20),
                  ],
                  if ((_page?['content'] as String?)?.isNotEmpty == true)
                    SimpleHtml(html: _page!['content'] as String),
                ],
              ),
            ),
    );
  }
}
