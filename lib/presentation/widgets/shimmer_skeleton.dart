import 'package:flutter/material.dart';

class ShimmerSkeleton extends StatefulWidget {
  const ShimmerSkeleton({
    super.key,
    this.height,
    this.width,
    this.borderRadius = 12,
    this.baseOpacity = 0.18,
    this.highlightOpacity = 0.35,
  });

  final double? height;
  final double? width;
  final double borderRadius;
  final double baseOpacity;
  final double highlightOpacity;

  @override
  State<ShimmerSkeleton> createState() => _ShimmerSkeletonState();
}

class _ShimmerSkeletonState extends State<ShimmerSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final base = colors.onSurface.withValues(alpha: widget.baseOpacity);
    final highlight = colors.onSurface.withValues(alpha: widget.highlightOpacity);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          height: widget.height,
          width: widget.width,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment(-1 - _controller.value * 2, 0),
              end: Alignment(1 - _controller.value * 2, 0),
              colors: [base, highlight, base],
              stops: const [0.1, 0.5, 0.9],
            ),
          ),
        );
      },
    );
  }
}
