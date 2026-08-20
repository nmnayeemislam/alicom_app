/// Every path here mirrors a route in the Laravel backend's
/// `routes/api.php` 1:1 — keep this file in sync with that file.
class ApiEndpoints {
  ApiEndpoints._();

  // Auth
  static const register = '/register';
  static const login = '/login';
  static const authCountries = '/auth/countries';
  static const authLoginOtp = '/auth/login-otp';
  static const authLoginOtpVerify = '/auth/login-otp/verify';
  static const authForgotPassword = '/auth/forgot-password';
  static const authVerifyOtp = '/auth/verify-otp';
  static const authResendOtp = '/auth/resend-otp';
  static const authResetPassword = '/auth/reset-password';
  static const logout = '/logout';
  static const profile = '/profile';
  static const profileFcmToken = '/profile/fcm-token';

  // Newsletter / contact / activity / search
  static const newsletter = '/newsletter';
  static String newsletterUnsubscribe(String token) => '/newsletter/$token';
  static const contactLeads = '/contact-leads';
  static const activityTrack = '/activity/track';
  static const searchLogs = '/search-logs';
  static const productsSearch = '/products/search';

  // Catalog / public
  static const homeFetchData = '/home/fetch-data';
  static const homeFeaturedCatalog = '/home/featured-catalog';
  static const footer = '/footer';
  static String page(String slug) => '/pages/$slug';
  static const categories = '/categories';
  static const brands = '/brands';
  static const products = '/products';
  static const productsDiscounted = '/products/discounted';
  static String product(String slug) => '/products/$slug';
  static String productReviews(String slug) => '/products/$slug/reviews';
  static const blogCategories = '/blog-categories';
  static const blogTags = '/blog-tags';
  static const blogPosts = '/blog-posts';
  static String blogPost(String slug) => '/blog-posts/$slug';
  static const coupons = '/coupons';
  static const banners = '/banners';
  static const heroBanners = '/hero-banners';
  static const flashSales = '/flash-sales';
  static const deliveryZones = '/delivery-zones';
  static const deliveryZoneCharge = '/delivery-zones/charge';
  static const paymentMethods = '/payment-methods';
  static const settingsMetaPixel = '/settings/meta-pixel';
  static const settingsBranding = '/settings/branding';

  // Commerce
  static const couponsCheck = '/coupons/check';
  static const ordersTracking = '/orders/tracking';
  static const checkoutOrder = '/checkout/order';
  static const customerOrder = '/customer/order';
  static const cart = '/cart';
  static const cartItems = '/cart/items';
  static String cartItem(int itemId) => '/cart/items/$itemId';

  // Customer (authenticated)
  static const addresses = '/addresses';
  static String address(int id) => '/addresses/$id';
  static String addressDefault(int id) => '/addresses/$id/default';
  static const myStats = '/my/stats';
  static const myOrders = '/my/orders';
  static String myOrder(int id) => '/my/orders/$id';
  static String myOrderCancel(int id) => '/my/orders/$id/cancel';
  static String myOrderRefundRequest(int id) =>
      '/my/orders/$id/refund-request';
  static const reviews = '/reviews';
  static const wishlist = '/wishlist';
  static String wishlistItem(int productId) => '/wishlist/$productId';
  static const wishlistToggle = '/wishlist/toggle';
  static String wishlistStatus(int productId) => '/wishlist/$productId/status';
}
