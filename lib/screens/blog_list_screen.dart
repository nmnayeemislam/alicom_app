import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../services/content_service.dart';
import '../theme/app_theme.dart';
import '../widgets/state_views.dart';
import 'blog_detail_screen.dart';

/// Mirrors BlogPostController@index — the storefront's articles/guides feed.
class BlogListScreen extends StatefulWidget {
  const BlogListScreen({super.key});

  @override
  State<BlogListScreen> createState() => _BlogListScreenState();
}

class _BlogListScreenState extends State<BlogListScreen> {
  bool _isLoading = true;
  String? _error;
  List<Map> _posts = [];

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
      final response = await ContentService.instance.blogPosts();
      final data = (response is Map ? response['data'] ?? response : {}) as Map;
      _posts = ((data['posts'] as List?) ?? []).map((e) => e as Map).toList();
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Blog')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _isLoading
            ? const LoadingView()
            : _error != null
            ? ErrorView(message: _error!, onRetry: _load)
            : _posts.isEmpty
            ? const EmptyView(icon: Icons.article_outlined, message: 'No articles yet.')
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: _posts.length,
                separatorBuilder: (_, __) => const SizedBox(height: 16),
                itemBuilder: (context, index) => _BlogCard(post: _posts[index]),
              ),
      ),
    );
  }
}

class _BlogCard extends StatelessWidget {
  final Map post;
  const _BlogCard({required this.post});

  @override
  Widget build(BuildContext context) {
    final slug = post['slug'] as String? ?? '';
    final title = post['title'] as String? ?? '';
    final excerpt = post['excerpt'] as String?;
    final image = post['image'] as String?;
    final category = post['category_name'] as String?;
    final readTime = post['read_time_minutes'] as int?;

    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => BlogDetailScreen(slug: slug)),
      ),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
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
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (category != null && category.isNotEmpty)
                    Text(
                      category.toUpperCase(),
                      style: TextStyle(color: AppColors.accentDark, fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 0.5),
                    ),
                  const SizedBox(height: 6),
                  Text(title, style: Theme.of(context).textTheme.titleSmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                  if (excerpt != null && excerpt.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      excerpt,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: AppColors.body, fontSize: 12.5, height: 1.4),
                    ),
                  ],
                  if (readTime != null) ...[
                    const SizedBox(height: 8),
                    Text('$readTime min read', style: TextStyle(color: AppColors.muted, fontSize: 11)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
