import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../services/content_service.dart';
import '../theme/app_theme.dart';
import '../widgets/simple_html.dart';
import '../widgets/state_views.dart';

/// Mirrors BlogPostController@show.
class BlogDetailScreen extends StatefulWidget {
  final String slug;
  const BlogDetailScreen({super.key, required this.slug});

  @override
  State<BlogDetailScreen> createState() => _BlogDetailScreenState();
}

class _BlogDetailScreenState extends State<BlogDetailScreen> {
  bool _isLoading = true;
  String? _error;
  Map? _post;

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
      final response = await ContentService.instance.blogPost(widget.slug);
      final data = (response is Map ? response['data'] ?? response : {}) as Map;
      _post = (data['post'] as Map?) ?? data;
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _post?['title'] as String?;
    return Scaffold(
      appBar: AppBar(title: Text(title ?? 'Article')),
      body: _isLoading
          ? const LoadingView()
          : _error != null
          ? ErrorView(message: _error!, onRetry: _load)
          : _post == null
          ? const EmptyView(icon: Icons.article_outlined, message: 'Article not found.')
          : _buildDetail(_post!),
    );
  }

  Widget _buildDetail(Map post) {
    final image = post['image'] as String?;
    final title = post['title'] as String? ?? '';
    final category = post['category_name'] as String?;
    final authorName = post['author_name'] as String?;
    final readTime = post['read_time_minutes'] as int?;
    final content = post['content'] as String?;

    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        if (image != null && image.isNotEmpty)
          AspectRatio(
            aspectRatio: 16 / 9,
            child: CachedNetworkImage(
              imageUrl: image,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(color: AppColors.background),
              errorWidget: (_, __, ___) => Container(
                color: AppColors.background,
                child: Icon(Icons.image_not_supported_outlined, color: AppColors.muted),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (category != null && category.isNotEmpty)
                Text(
                  category.toUpperCase(),
                  style: TextStyle(color: AppColors.accentDark, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5),
                ),
              const SizedBox(height: 8),
              Text(title, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.inkStrong)),
              const SizedBox(height: 10),
              Row(
                children: [
                  if (authorName != null && authorName.isNotEmpty) ...[
                    Icon(Icons.person_outline, size: 14, color: AppColors.muted),
                    const SizedBox(width: 4),
                    Text(authorName, style: TextStyle(color: AppColors.muted, fontSize: 12.5)),
                  ],
                  if (readTime != null) ...[
                    const SizedBox(width: 14),
                    Icon(Icons.schedule, size: 14, color: AppColors.muted),
                    const SizedBox(width: 4),
                    Text('$readTime min read', style: TextStyle(color: AppColors.muted, fontSize: 12.5)),
                  ],
                ],
              ),
              const SizedBox(height: 20),
              if (content != null && content.isNotEmpty) SimpleHtml(html: content),
            ],
          ),
        ),
      ],
    );
  }
}
