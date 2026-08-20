import 'package:flutter/material.dart';

import '../services/catalog_service.dart';
import '../state/auth_state.dart';
import '../theme/app_theme.dart';
import '../widgets/state_views.dart';
import '../widgets/write_review_sheet.dart';
import 'notifications_screen.dart';

enum _ReviewFilter { all, withPhotos, highestRated }

/// Full-screen ratings breakdown + review list for a product, reached from
/// ProductDetailScreen's reviews section. Mirrors ReviewController's
/// per-product review listing.
class ReviewsScreen extends StatefulWidget {
  final String slug;
  final int? productId;
  final String? productTitle;

  const ReviewsScreen({
    super.key,
    required this.slug,
    this.productId,
    this.productTitle,
  });

  @override
  State<ReviewsScreen> createState() => _ReviewsScreenState();
}

class _ReviewsScreenState extends State<ReviewsScreen> {
  bool _isLoading = true;
  String? _error;
  List<Map> _reviews = [];
  Map? _summary;
  _ReviewFilter _filter = _ReviewFilter.all;

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
      final response = await CatalogService.instance.productReviews(widget.slug);
      final data = (response is Map ? response['data'] ?? response : {}) as Map;
      _reviews = ((data['reviews'] as List?) ?? []).map((e) => e as Map).toList();
      _summary = data['summary'] as Map?;
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _openWriteReview() async {
    final productId = widget.productId;
    if (productId == null) return;
    if (!AuthState.instance.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in to write a review.')),
      );
      return;
    }
    final submitted = await showWriteReviewSheet(context, productId: productId);
    if (submitted == true) _load();
  }

  double get _average {
    final fromSummary = (_summary?['average'] as num?)?.toDouble();
    if (fromSummary != null) return fromSummary;
    if (_reviews.isEmpty) return 0;
    final sum = _reviews.fold<double>(0, (s, r) => s + ((r['rating'] as num?)?.toDouble() ?? 0));
    return sum / _reviews.length;
  }

  int get _total => (_summary?['total'] as num?)?.toInt() ?? _reviews.length;

  Map<int, int> get _breakdown {
    final counts = {5: 0, 4: 0, 3: 0, 2: 0, 1: 0};
    for (final r in _reviews) {
      final rating = ((r['rating'] as num?)?.toInt() ?? 0).clamp(0, 5);
      if (rating > 0) counts[rating] = (counts[rating] ?? 0) + 1;
    }
    return counts;
  }

  List<Map> get _filteredReviews {
    var list = List<Map>.from(_reviews);
    switch (_filter) {
      case _ReviewFilter.withPhotos:
        list = list.where((r) {
          final photos = r['photos'] ?? r['images'];
          return photos is List && photos.isNotEmpty;
        }).toList();
        break;
      case _ReviewFilter.highestRated:
        list.sort((a, b) => ((b['rating'] as num?) ?? 0).compareTo((a['rating'] as num?) ?? 0));
        break;
      case _ReviewFilter.all:
        break;
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ALICOM', style: TextStyle(letterSpacing: 3, fontWeight: FontWeight.w700)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const NotificationsScreen()),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const LoadingView()
          : _error != null
          ? ErrorView(message: _error!, onRetry: _load)
          : Stack(
              children: [
                RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 90),
                    children: [
                      InkWell(
                        onTap: () => Navigator.of(context).maybePop(),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.arrow_back, size: 16, color: AppColors.body),
                            const SizedBox(width: 6),
                            Text('Back to Product', style: TextStyle(color: AppColors.body)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text('Reviews & Ratings', style: Theme.of(context).textTheme.headlineSmall ??
                          Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 16),
                      _buildSummaryCard(),
                      const SizedBox(height: 20),
                      _buildFilterRow(),
                      const SizedBox(height: 12),
                      if (_filteredReviews.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 40),
                          child: Center(
                            child: Text('No reviews match this filter.', style: TextStyle(color: AppColors.muted)),
                          ),
                        )
                      else
                        ..._filteredReviews.map((r) => _ReviewCard(review: r)),
                    ],
                  ),
                ),
                Positioned(
                  right: 20,
                  bottom: 20,
                  child: ElevatedButton.icon(
                    onPressed: _openWriteReview,
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text('Write a Review'),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSummaryCard() {
    final breakdown = _breakdown;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        children: [
          Text(
            _average.toStringAsFixed(1),
            style: TextStyle(fontSize: 34, fontWeight: FontWeight.w700, color: AppColors.inkStrong),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final filled = i < _average.round();
              return Icon(filled ? Icons.star : Icons.star_border, size: 18, color: AppColors.primary);
            }),
          ),
          const SizedBox(height: 6),
          Text('Based on $_total reviews', style: TextStyle(color: AppColors.muted, fontSize: 12.5)),
          const SizedBox(height: 18),
          ...List.generate(5, (i) {
            final star = 5 - i;
            final count = breakdown[star] ?? 0;
            final ratio = _total > 0 ? count / _total : 0.0;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(width: 44, child: Text('$star stars', style: TextStyle(fontSize: 12, color: AppColors.body))),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: ratio,
                        minHeight: 6,
                        backgroundColor: AppColors.line,
                        valueColor: AlwaysStoppedAnimation(AppColors.primary),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 28,
                    child: Text('$count', textAlign: TextAlign.right, style: TextStyle(fontSize: 12, color: AppColors.muted)),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildFilterRow() {
    Widget chip(String label, _ReviewFilter value) {
      final active = _filter == value;
      return Padding(
        padding: const EdgeInsets.only(right: 10),
        child: InkWell(
          onTap: () => setState(() => _filter = value),
          borderRadius: BorderRadius.circular(999),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: active ? AppColors.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: active ? AppColors.primary : AppColors.line),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: active ? AppColors.onAccent : AppColors.ink,
              ),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          chip('All Reviews', _ReviewFilter.all),
          chip('With Photos', _ReviewFilter.withPhotos),
          chip('Highest Rated', _ReviewFilter.highestRated),
        ],
      ),
    );
  }
}

class _ReviewCard extends StatefulWidget {
  final Map review;
  const _ReviewCard({required this.review});

  @override
  State<_ReviewCard> createState() => _ReviewCardState();
}

class _ReviewCardState extends State<_ReviewCard> {
  bool _marked = false;

  @override
  Widget build(BuildContext context) {
    final r = widget.review;
    final name = r['reviewer_name'] as String? ?? 'Customer';
    final rating = ((r['rating'] as num?)?.toInt() ?? 0).clamp(0, 5);
    final title = r['title'] as String?;
    final comment = r['comment'] as String?;
    final verified = r['is_verified'] == true;
    final date = r['created_at'] as String?;
    final photos = ((r['photos'] ?? r['images']) as List?)?.whereType<String>().toList() ?? [];
    final helpful = (r['helpful_count'] as num?)?.toInt() ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
              if (verified) ...[
                const SizedBox(width: 4),
                Icon(Icons.verified, size: 14, color: AppColors.primary),
              ],
              const Spacer(),
              if (date != null)
                Text(_formatDate(date), style: TextStyle(color: AppColors.muted, fontSize: 11.5)),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: List.generate(
              5,
              (i) => Icon(
                i < rating ? Icons.star : Icons.star_border,
                size: 14,
                color: AppColors.primary,
              ),
            ),
          ),
          if (title != null && title.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
          if (comment != null && comment.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(comment, style: TextStyle(color: AppColors.body, height: 1.4)),
          ],
          if (photos.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 56,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: photos.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) => ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(photos[i], width: 56, height: 56, fit: BoxFit.cover),
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          InkWell(
            onTap: () => setState(() => _marked = !_marked),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _marked ? Icons.thumb_up : Icons.thumb_up_outlined,
                  size: 14,
                  color: _marked ? AppColors.primary : AppColors.muted,
                ),
                const SizedBox(width: 6),
                Text(
                  'Helpful (${helpful + (_marked ? 1 : 0)})',
                  style: TextStyle(fontSize: 12, color: _marked ? AppColors.primary : AppColors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String raw) {
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    final diff = DateTime.now().difference(parsed);
    if (diff.inDays >= 14) return '${diff.inDays ~/ 7} weeks ago';
    if (diff.inDays >= 1) return '${diff.inDays} day${diff.inDays == 1 ? '' : 's'} ago';
    if (diff.inHours >= 1) return '${diff.inHours}h ago';
    return 'Just now';
  }
}
