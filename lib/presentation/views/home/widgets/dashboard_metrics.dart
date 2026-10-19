import 'package:flutter/material.dart';

class DashboardMetricData {
  const DashboardMetricData({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.subtitle,
    this.progress,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String? subtitle;
  final double? progress;
  final VoidCallback? onTap;
}

class DashboardMetrics extends StatelessWidget {
  const DashboardMetrics({
    super.key,
    required this.metrics,
    required this.useWrap,
    this.condensed = false,
    this.isLoading = false,
  });

  final List<DashboardMetricData> metrics;
  final bool useWrap;
  final bool condensed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return DashboardMetricsSkeleton(useWrap: useWrap, condensed: condensed);
    }

    final cards = metrics
        .map(
          (m) => _DashboardMetricCard(
            data: m,
            condensed: condensed,
          ),
        )
        .toList();

    if (useWrap) {
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: cards,
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: cards
            .expand((w) sync* {
              yield w;
              yield const SizedBox(width: 12);
            })
            .toList()
          ..removeLast(),
      ),
    );
  }
}

class DashboardMetricsSkeleton extends StatelessWidget {
  const DashboardMetricsSkeleton({
    super.key,
    required this.useWrap,
    required this.condensed,
  });

  final bool useWrap;
  final bool condensed;

  @override
  Widget build(BuildContext context) {
    final shimmerColor =
        Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.6);
    final box = _MetricSkeletonBox(color: shimmerColor, condensed: condensed);

    if (useWrap) {
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: List.generate(3, (_) => box),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: List.generate(
          3,
          (_) => Padding(
            padding: const EdgeInsets.only(right: 12),
            child: box,
          ),
        ),
      ),
    );
  }
}

class _DashboardMetricCard extends StatelessWidget {
  const _DashboardMetricCard({
    required this.data,
    required this.condensed,
  });

  final DashboardMetricData data;
  final bool condensed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final theme = Theme.of(context).textTheme;
    final scale = condensed ? 0.95 : 1.0;
    final progress = data.progress?.clamp(0.0, 1.0);

    return AnimatedScale(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      scale: scale,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        width: 210,
        padding: EdgeInsets.all(condensed ? 12 : 16),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: colors.outlineVariant.withValues(alpha: 0.35),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: InkWell(
          onTap: data.onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        data.value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.displaySmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          height: 1.05,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: data.color.withValues(alpha: 0.16),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        data.icon,
                        color: data.color,
                        size: 20,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      data.label,
                      style: theme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colors.onSurface,
                      ),
                    ),
                    if (data.onTap != null) ...[
                      const SizedBox(width: 4),
                      Icon(Icons.chevron_right,
                          size: 16, color: colors.onSurfaceVariant),
                    ],
                  ],
                ),
                if (data.subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    data.subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.labelSmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
                if (progress != null) ...[
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      color: data.color,
                      backgroundColor: colors.surfaceContainerHigh,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MetricSkeletonBox extends StatelessWidget {
  const _MetricSkeletonBox({
    required this.color,
    required this.condensed,
  });

  final Color color;
  final bool condensed;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 200,
      height: condensed ? 120 : 140,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(18),
      ),
    );
  }
}
