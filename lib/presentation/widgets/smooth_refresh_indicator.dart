import 'package:flutter/material.dart';

/// Lightweight wrapper over [RefreshIndicator] with tuned defaults so the
/// pull-to-refresh spinner feels smoother and less jumpy.
class SmoothRefreshIndicator extends StatelessWidget {
  const SmoothRefreshIndicator({
    super.key,
    required this.onRefresh,
    required this.child,
    this.edgeOffset = 12,
  });

  final Future<void> Function() onRefresh;
  final Widget child;
  final double edgeOffset;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return RefreshIndicator(
      onRefresh: onRefresh,
      edgeOffset: edgeOffset,
      displacement: edgeOffset + 14,
      strokeWidth: 2.6,
      color: colors.primary,
      backgroundColor: colors.surface,
      child: child,
    );
  }
}
