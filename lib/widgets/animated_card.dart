import 'package:flutter/material.dart';

class StaggeredEntry extends StatelessWidget {
  final int index;
  final Widget child;

  const StaggeredEntry({
    super.key,
    required this.index,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 240 + (index.clamp(0, 8) * 35)),
      curve: Curves.easeOutCubic,
      builder: (context, value, animChild) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, (1.0 - value) * 12),
          child: animChild,
        ),
      ),
      child: child,
    );
  }
}

class PressableCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final Color? color;

  const PressableCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding,
    this.color,
  });

  @override
  State<PressableCard> createState() => _PressableCardState();
}

class _PressableCardState extends State<PressableCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOutCubic,
        child: Card(
          color: widget.color,
          child: widget.padding != null
              ? Padding(padding: widget.padding!, child: widget.child)
              : widget.child,
        ),
      ),
    );
  }
}
