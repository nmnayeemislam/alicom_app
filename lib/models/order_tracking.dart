/// One stage of an order's journey, from `GET /orders/tracking`.
class OrderStage {
  final String status;

  /// Already reached — includes the current one.
  final bool isCompleted;
  final bool isCurrent;

  /// The backend's own wording ("42 minutes ago"); null until reached.
  final String? changedAt;

  const OrderStage({
    required this.status,
    this.isCompleted = false,
    this.isCurrent = false,
    this.changedAt,
  });

  factory OrderStage.fromJson(Map<String, dynamic> json) => OrderStage(
        status: json['status'] as String? ?? '',
        isCompleted: json['is_completed'] == true,
        isCurrent: json['is_current'] == true,
        changedAt: json['changed_at'] as String?,
      );
}

/// The whole flow for one order: every stage it passes through, and where
/// it has got to.
///
/// The flow depends only on the order's type, so the list screen fetches it
/// once and reuses it for every order of that kind.
class OrderTracking {
  final String orderCode;
  final String currentStatus;
  final bool isRegularOrder;
  final List<OrderStage> stages;

  const OrderTracking({
    this.orderCode = '',
    this.currentStatus = '',
    this.isRegularOrder = true,
    this.stages = const [],
  });

  /// How many stages are done, including the current one.
  int get completedCount => stages.where((s) => s.isCompleted).length;

  /// 0..1 — the current stage counts as reached, so a brand new order is
  /// already a fraction of the way along rather than showing empty.
  double get progress =>
      stages.isEmpty ? 0 : (completedCount / stages.length).clamp(0.0, 1.0);

  /// Index of the stage the order sits on, or -1 when the status is not in
  /// the flow at all (cancelled, refunded).
  int get currentIndex => stages.indexWhere((s) => s.isCurrent);

  factory OrderTracking.fromJson(Map<String, dynamic> json) => OrderTracking(
        orderCode: json['order_code'] as String? ?? '',
        currentStatus: json['current_status'] as String? ?? '',
        isRegularOrder: json['is_regular_order'] != false,
        stages: ((json['status_flow'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => OrderStage.fromJson(e.cast<String, dynamic>()))
            .toList(),
      );
}
