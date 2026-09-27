import 'package:flutter/material.dart';

import '../models/order_tracking.dart';
import '../theme/app_theme.dart';

/// The order's journey as a vertical timeline: stages already passed carry
/// a filled tick and the time they happened, the one it sits on is bold and
/// ringed, and everything still ahead is greyed out.
class OrderStageTracker extends StatelessWidget {
  final OrderTracking tracking;

  const OrderStageTracker({super.key, required this.tracking});

  @override
  Widget build(BuildContext context) {
    final stages = tracking.stages;
    if (stages.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < stages.length; i++)
          _StageRow(
            stage: stages[i],
            isFirst: i == 0,
            isLast: i == stages.length - 1,
            // The line above a stage is "done" when the stage before it was.
            previousDone: i > 0 && stages[i - 1].isCompleted,
          ),
      ],
    );
  }
}

class _StageRow extends StatelessWidget {
  final OrderStage stage;
  final bool isFirst;
  final bool isLast;
  final bool previousDone;

  const _StageRow({
    required this.stage,
    required this.isFirst,
    required this.isLast,
    required this.previousDone,
  });

  @override
  Widget build(BuildContext context) {
    final done = stage.isCompleted;
    final current = stage.isCurrent;
    final accent = AppColors.primary;
    final dull = AppColors.lineStrong;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 28,
            child: Column(
              children: [
                // Connector up to the previous stage.
                Container(
                  width: 2,
                  height: 6,
                  color: isFirst ? Colors.transparent : (previousDone ? accent : dull),
                ),
                _Dot(done: done, current: current, accent: accent, dull: dull),
                if (!isLast)
                  Expanded(
                    child: Container(width: 2, color: done ? accent : dull),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: 4, bottom: isLast ? 0 : 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stage.status,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: current ? FontWeight.w800 : FontWeight.w600,
                      color: done ? AppColors.inkStrong : AppColors.muted,
                    ),
                  ),
                  if (stage.changedAt != null && stage.changedAt!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      stage.changedAt!,
                      style: TextStyle(fontSize: 11.5, color: AppColors.muted),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  final bool done;
  final bool current;
  final Color accent;
  final Color dull;

  const _Dot({required this.done, required this.current, required this.accent, required this.dull});

  @override
  Widget build(BuildContext context) {
    if (current) {
      // A ring, so the stage the order is on reads differently from the
      // ones it has already been through.
      return Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: accent.withValues(alpha: 0.16),
          border: Border.all(color: accent, width: 2),
        ),
        child: Center(
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
          ),
        ),
      );
    }
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: done ? accent : Colors.transparent,
        border: done ? null : Border.all(color: dull, width: 2),
      ),
      child: done ? const Icon(Icons.check_rounded, size: 14, color: Colors.white) : null,
    );
  }
}

/// A slim bar for the order list: how far along, plus "stage 2 of 6".
class OrderStageBar extends StatelessWidget {
  final OrderTracking tracking;

  const OrderStageBar({super.key, required this.tracking});

  @override
  Widget build(BuildContext context) {
    final total = tracking.stages.length;
    if (total == 0) return const SizedBox.shrink();
    final done = tracking.completedCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: List.generate(total, (i) {
            final reached = i < done;
            return Expanded(
              child: Container(
                height: 4,
                margin: EdgeInsets.only(right: i == total - 1 ? 0 : 3),
                decoration: BoxDecoration(
                  color: reached ? AppColors.primary : AppColors.line,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 6),
        Text(
          'Step $done of $total · ${tracking.currentStatus}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 11.5, color: AppColors.muted),
        ),
      ],
    );
  }
}
