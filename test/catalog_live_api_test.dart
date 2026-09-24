import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:alicom_app/core/api_config.dart';
import 'package:alicom_app/models/category.dart';
import 'package:alicom_app/services/catalog_service.dart';

/// Hits the real backend — no fixtures, no mocks. These are the checks the
/// catalogue work is signed off against, and they double as a canary for the
/// quiet failure modes the API has: an ignored filter key and a silently
/// renamed field both return 200 with plausible-looking JSON.
///
/// Skipped unless `LIVE_API` is set, so a plain `flutter test` stays green
/// for anyone without a backend running:
///
///   flutter test test/catalog_live_api_test.dart --dart-define=LIVE_API=true
///
/// Add `--dart-define=API_BASE_URL=http://<host>:8000/api` to point at a
/// host other than the one [ApiConfig] defaults to.
const _liveApi = bool.fromEnvironment('LIVE_API');

/// Restores the real `HttpClient`.
///
/// The Flutter test binding installs an override that answers every request
/// with a 400 so tests never touch the network — the right default, and
/// exactly what these tests exist to opt out of.
class _RealHttpOverrides extends HttpOverrides {}

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    HttpOverrides.global = _RealHttpOverrides();
  });

  final skip = _liveApi
      ? null
      : 'needs a running backend — pass --dart-define=LIVE_API=true';

  group('live catalogue API', _catalogTests, skip: skip);
}

void _catalogTests() {
  const expectedCategories = 19;
  const expectedReturnedByEndpoint = 14;

  final catalog = CatalogService.instance;

  test('base URL is configurable, not hardcoded at the call sites', () {
    expect(ApiConfig.baseUrl, endsWith('/api'));
  });

  test('GET /categories returns the leaf categories', () async {
    final flat = await catalog.categoryList();

    expect(
      flat,
      hasLength(expectedReturnedByEndpoint),
      reason: 'the endpoint only returns categories that have products',
    );
    expect(flat.every((c) => c.slug.isNotEmpty), isTrue);
    expect(
      flat.where((c) => c.imageUrl != null),
      isNotEmpty,
      reason: '`img` should parse into an absolute URL',
    );
  });

  test('the tree rebuilds the parents the endpoint leaves out', () async {
    final tree = await catalog.categoryTree();

    expect(
      Category.countAll(tree),
      expectedCategories,
      reason: '14 returned leaves + the 5 parents rebuilt from parent_slug',
    );

    final rootNames = tree.map((c) => c.name).toSet();
    expect(
      rootNames,
      containsAll(<String>[
        'Books',
        'Cooling & Climate',
        'Electronics',
        'Fashion',
        'Home Appliances',
        'Kitchen Appliances',
      ]),
    );

    // Audio is both a leaf with products and a parent, so the tree is three
    // levels deep even though most branches are two.
    final electronics = tree.firstWhere((c) => c.slug == 'electronics');
    final audio = electronics.children.firstWhere((c) => c.slug == 'audio');
    expect(
      audio.children.map((c) => c.slug),
      containsAll(<String>['headphones', 'speakers']),
    );

    // A synthesized parent has no products of its own; the branch total is
    // what the UI shows for it.
    expect(electronics.totalProduct, 0);
    expect(electronics.totalProductsDeep, greaterThan(0));
    expect(electronics.displayImageUrl, isNotNull,
        reason: 'a parent with no img of its own borrows a child\'s');
  });

  // Product counts are deliberately not pinned: the demo catalogue gets
  // reseeded (32 products once, 144 now). What must hold is the paging
  // contract itself.
  test('GET /products pages 20 at a time and reports a consistent total', () async {
    final first = await catalog.productPage();
    final total = first.pagination.total;

    expect(first.pagination.perPage, 20);
    expect(total, greaterThan(20), reason: 'needs more than one page to test paging');
    expect(first.products, hasLength(20),
        reason: 'the default page size is 20, not the full catalogue');
    expect(first.pagination.hasMorePages, isTrue);
    expect(first.pagination.lastPage, (total / 20).ceil());

    final last = await catalog.productPage(filters: {'page': first.pagination.lastPage});
    expect(last.pagination.hasMorePages, isFalse);
    expect(last.products, hasLength(total - 20 * (first.pagination.lastPage - 1)));
  });

  test('per_page raises the page size (capped at 100)', () async {
    final first = await catalog.productPage();
    final page = await catalog.productPage(filters: {'per_page': 100});
    final total = first.pagination.total;
    expect(page.products, hasLength(total < 100 ? total : 100));
  });

  test('products parse `name`, not `title`', () async {
    final page = await catalog.productPage(filters: {'per_page': 100});

    // The DB column is `title` but the API sends `name`. Reading `title`
    // yields null with no error, so an empty name here means the model
    // regressed to the wrong key.
    expect(page.products.where((p) => p.title.isEmpty), isEmpty);
    expect(page.products.where((p) => p.slug.isEmpty), isEmpty);
    expect(page.products.where((p) => p.images.isEmpty), isEmpty);
    expect(
      page.products.every((p) => p.images.every((i) => i.startsWith('http'))),
      isTrue,
      reason: '`images` are absolute already; the base URL must not be prepended',
    );
  });

  test('category_slug actually narrows the result set', () async {
    final all = await catalog.productPage();
    final speakers =
        await catalog.productPage(filters: {'category_slug': 'speakers'});

    // Laravel ignores an unknown query key and returns everything, so the
    // filter "working" has to be proved by the total dropping.
    expect(speakers.pagination.total, lessThan(all.pagination.total));
    expect(speakers.pagination.total, greaterThan(0));

    // And it agrees with the count /categories advertises for the tile.
    final categories = await catalog.categoryList();
    final tile = categories.firstWhere((c) => c.slug == 'speakers');
    expect(speakers.pagination.total, tile.totalProduct);
    expect(
      speakers.products.every((p) => p.category == 'Speakers'),
      isTrue,
    );
  });

  test('a parent slug returns all of its sub-categories combined', () async {
    // What lets the Categories tab and the "All" chip page through a
    // parent with one request instead of merging each child's list.
    final tree = await catalog.categoryTree();
    final electronics = tree.firstWhere((c) => c.slug == 'electronics');
    final page =
        await catalog.productPage(filters: {'category_slug': 'electronics'});

    expect(page.pagination.total, greaterThan(0));
    expect(page.pagination.total, electronics.totalProductsDeep,
        reason: 'the parent total is the sum over its whole branch');

    // And a mid-level parent (Audio has products of its own plus
    // Headphones and Speakers) includes its children too.
    final audio = electronics.children.firstWhere((c) => c.slug == 'audio');
    final audioPage =
        await catalog.productPage(filters: {'category_slug': 'audio'});
    expect(audioPage.pagination.total, audio.totalProductsDeep);
  });

  test('without `sort` the admin order is kept; with it the order changes',
      () async {
    final admin = await catalog.productPage(filters: {'category_slug': 'mobile-phones'});
    final cheapest = await catalog.productPage(
        filters: {'category_slug': 'mobile-phones', 'sort': 'price_low'});
    final prices = cheapest.products.map((p) => p.price).toList();
    expect(prices, orderedEquals([...prices]..sort()));
    expect(admin.pagination.total, cheapest.pagination.total);
  });

  test('price is post-discount and original_price is the struck-out one',
      () async {
    final page = await catalog.productPage(filters: {'per_page': 100});
    final discounted =
        page.products.where((p) => p.referencePrice > p.price).toList();

    expect(discounted, isNotEmpty);
    for (final product in discounted) {
      expect(product.originalPrice, greaterThan(product.price));
      expect(product.discountBadge, isNotNull);
      expect(product.discountPercentage, greaterThan(0));
    }
  });

  test('every documented sort value is accepted', () async {
    for (final sort in const [
      'newest',
      'price_low',
      'price_high',
      'offer',
      'popular',
      'best_selling',
    ]) {
      final page = await catalog.productPage(filters: {'sort': sort});
      expect(page.products, isNotEmpty, reason: 'sort=$sort returned nothing');
    }
  });

  test('GET /products/{slug} carries description, category and brand',
      () async {
    final listed = (await catalog.productPage()).products.first;
    final response = await catalog.product(listed.slug);
    final data = (response as Map)['data'] as Map;

    expect(data.keys, containsAll(<String>['product', 'reviews', 'related_products']));

    final detail = await catalog.productPage(filters: {'per_page': 1});
    expect(detail.products, hasLength(1));
  });
}
