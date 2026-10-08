import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Snapping behaviour for a pinned, expandable [SliverAppBar] header — the
/// banner at the top of the details pages.
///
/// When scrolling comes to rest part-way through the collapse, the header
/// animates to fully expanded or fully collapsed, whichever is nearer (as iOS
/// large titles do), so it never rests half-open.
///
/// Wrap the [CustomScrollView] or [NestedScrollView] whose outer scroll
/// position [controller] drives. Pair it with [fullCollapseFiller] in a plain
/// [CustomScrollView] so short pages can still collapse fully. (A
/// [NestedScrollView] header can always collapse fully, so it needs none.)
class CollapsingHeaderSnap extends StatefulWidget {
  final ScrollController controller;
  final double expandedHeight;
  final Widget child;

  const CollapsingHeaderSnap({
    super.key,
    required this.controller,
    required this.expandedHeight,
    required this.child,
  });

  /// Scroll offset at which the header has fully collapsed to the toolbar.
  static double collapseExtentOf(BuildContext context, double expandedHeight) {
    final collapsedHeight = kToolbarHeight + MediaQuery.paddingOf(context).top;
    return math.max(0, expandedHeight - collapsedHeight);
  }

  /// A trailing sliver that pads short content just enough for the header to
  /// collapse fully. Zero-height whenever the content is already long enough.
  static Widget fullCollapseFiller({required double expandedHeight}) {
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final needed = constraints.viewportMainAxisExtent +
            collapseExtentOf(context, expandedHeight) -
            constraints.precedingScrollExtent;
        return SliverToBoxAdapter(
          child: SizedBox(height: math.max(0, needed)),
        );
      },
    );
  }

  @override
  State<CollapsingHeaderSnap> createState() => _CollapsingHeaderSnapState();
}

class _CollapsingHeaderSnapState extends State<CollapsingHeaderSnap> {
  /// True from scheduling a snap until its animation finishes or is
  /// interrupted. The snap's own animation ends scrolls too — in a
  /// [NestedScrollView] the inner lists, already at their target, end
  /// instantly — and reacting to those would restart the snap before it ever
  /// moves, in an endless microtask loop that freezes the app.
  bool _snapping = false;

  bool _onScrollEnd(ScrollEndNotification notification) {
    // Horizontal rails (cast, tabs' PageView) end scrolls too; only vertical
    // scrolling moves the header. In a NestedScrollView the gesture ends on the
    // inner tab list, so any depth is accepted and the outer offset is read
    // from [controller].
    if (_snapping) return false;
    if (notification.metrics.axis != Axis.vertical) return false;
    final controller = widget.controller;
    if (!controller.hasClients) return false;

    final collapseExtent = CollapsingHeaderSnap.collapseExtentOf(
      context,
      widget.expandedHeight,
    );
    final position = controller.position;
    final offset = position.pixels;
    const tolerance = 0.5;
    if (offset <= tolerance || offset >= collapseExtent - tolerance) {
      return false;
    }

    // Content too short to collapse fully (no filler) can't reach the
    // collapsed offset; aim for where it can go, and stay put if already there.
    final target = (offset < collapseExtent / 2 ? 0.0 : collapseExtent)
        .clamp(position.minScrollExtent, position.maxScrollExtent);
    if ((target - offset).abs() <= tolerance) return false;

    _snapping = true;
    // Start after the ending activity has fully settled.
    scheduleMicrotask(() {
      if (!mounted || !controller.hasClients) {
        _snapping = false;
        return;
      }
      // Completes when the animation finishes or a touch interrupts it.
      controller
          .animateTo(
            target,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
          )
          .whenComplete(() => _snapping = false);
    });
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollEndNotification>(
      onNotification: _onScrollEnd,
      child: widget.child,
    );
  }
}
