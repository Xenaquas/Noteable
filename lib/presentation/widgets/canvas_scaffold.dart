import 'dart:math';

import 'package:flutter/material.dart';

/// Shared scaffold for editor-style pages with a scrollable canvas plus a
/// persistent bottom bar that respects the keyboard.
class CanvasScaffold extends StatelessWidget {
  const CanvasScaffold({
    super.key,
    required this.appBar,
    required this.slivers,
    this.bottomBar,
    this.backgroundColor,
    this.floatingActionButton,
  });

  final PreferredSizeWidget appBar;
  final List<Widget> slivers;
  final Widget? bottomBar;
  final Color? backgroundColor;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    return Scaffold(
      backgroundColor: backgroundColor ?? Theme.of(context).colorScheme.surface,
      appBar: appBar,
      floatingActionButton: floatingActionButton,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: slivers,
        ),
      ),
      bottomNavigationBar: bottomBar == null
          ? null
          : AnimatedPadding(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              padding: EdgeInsets.only(bottom: max(viewInsets - 8, 0)),
              child: bottomBar,
            ),
    );
  }
}
