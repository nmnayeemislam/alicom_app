import '../core/api_client.dart';
import '../core/api_endpoints.dart';

/// Authenticated: submit a product review. Mirrors ReviewController@store.
class ReviewService {
  ReviewService._();
  static final ReviewService instance = ReviewService._();

  Future<dynamic> submit({
    required int productId,
    required int rating,
    String? comment,
  }) async =>
      (await ApiClient.instance.post(
        ApiEndpoints.reviews,
        data: {
          'product_id': productId,
          'rating': rating,
          'comment': ?comment,
        },
      )).data;
}

/// Newsletter signup / one-click unsubscribe. Mirrors NewsletterController.
class NewsletterService {
  NewsletterService._();
  static final NewsletterService instance = NewsletterService._();

  Future<void> subscribe(String email) async {
    await ApiClient.instance.post(ApiEndpoints.newsletter, data: {'email': email});
  }

  Future<void> unsubscribe(String token) async {
    await ApiClient.instance.delete(ApiEndpoints.newsletterUnsubscribe(token));
  }
}

/// "Contact us" lead capture. Mirrors ContactLeadController@store.
class ContactLeadService {
  ContactLeadService._();
  static final ContactLeadService instance = ContactLeadService._();

  Future<void> submit(Map<String, dynamic> payload) async {
    await ApiClient.instance.post(ApiEndpoints.contactLeads, data: payload);
  }
}

/// Client-originated analytics events (guest visitor_uuid or authenticated).
/// Mirrors ActivityTrackController@store — only event types allowed by
/// ActivityEventType::clientSubmittable() on the backend will be accepted.
class ActivityTrackService {
  ActivityTrackService._();
  static final ActivityTrackService instance = ActivityTrackService._();

  Future<void> track({
    required String eventType,
    Map<String, dynamic>? payload,
  }) async {
    await ApiClient.instance.post(
      ApiEndpoints.activityTrack,
      data: {'event_type': eventType, ...?payload},
    );
  }
}

/// Records a storefront search query. Mirrors SearchLogController@store.
class SearchLogService {
  SearchLogService._();
  static final SearchLogService instance = SearchLogService._();

  Future<void> log(String query, {int? resultCount}) async {
    await ApiClient.instance.post(
      ApiEndpoints.searchLogs,
      data: {
        'query': query,
        'result_count': ?resultCount,
      },
    );
  }
}
