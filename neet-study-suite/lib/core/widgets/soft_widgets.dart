import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A press-responsive wrapper that gently scales its child on tap — gives a
/// tactile, "floating surface" feel across the whole app.
class TapScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scale;
  const TapScale({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scale = 0.96,
  });

  @override
  State<TapScale> createState() => _TapScaleState();
}

class _TapScaleState extends State<TapScale> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.onTap == null ? null : (_) => setState(() => _pressed = true),
      onTapUp: widget.onTap == null ? null : (_) => setState(() => _pressed = false),
      onTapCancel: widget.onTap == null ? null : () => setState(() => _pressed = false),
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: AnimatedScale(
        scale: _pressed ? widget.scale : 1.0,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// A soft, floating card with rounded corners and a gentle shadow.
/// The default surface used everywhere instead of plain Material cards.
class SoftCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Color? color;
  final Gradient? gradient;
  final double radius;
  final List<BoxShadow>? shadow;
  final Border? border;
  final bool showBorder;

  const SoftCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.onTap,
    this.onLongPress,
    this.color,
    this.gradient,
    this.radius = AppTheme.rLg,
    this.shadow,
    this.border,
    this.showBorder = true,
  });

  @override
  Widget build(BuildContext context) {
    AppTheme.syncFrom(context);
    final card = AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      padding: padding,
      decoration: BoxDecoration(
        color: gradient == null ? (color ?? AppTheme.cardBg) : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: shadow ?? AppTheme.cardShadow,
        border: border ?? (showBorder && gradient == null ? Border.all(color: AppTheme.line) : null),
      ),
      child: child,
    );
    if (onTap == null && onLongPress == null) return card;
    return TapScale(onTap: onTap, onLongPress: onLongPress, child: card);
  }
}

/// Soft pill-shaped chip/tag.
class SoftChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color? color;
  final bool filled;
  final VoidCallback? onTap;

  const SoftChip({
    super.key,
    required this.label,
    this.icon,
    this.color,
    this.filled = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = this.color ?? AppTheme.primary;
    final child = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: filled ? color : color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: filled ? Colors.white : color),
            const SizedBox(width: 6),
          ],
          Text(label, style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: filled ? Colors.white : color,
          )),
        ],
      ),
    );
    return onTap == null ? child : TapScale(onTap: onTap, child: child);
  }
}

/// A flowing gradient hero header with organic decorative blobs.
class GradientHeader extends StatelessWidget {
  final Gradient gradient;
  final Widget child;
  final double height;
  final EdgeInsetsGeometry padding;

  const GradientHeader({
    super.key,
    required this.gradient,
    required this.child,
    this.height = 220,
    this.padding = const EdgeInsets.fromLTRB(22, 60, 22, 28),
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(AppTheme.rXl)),
      child: Container(
        height: height,
        decoration: BoxDecoration(gradient: gradient),
        child: Stack(
          children: [
            // Decorative floating blobs
            Positioned(top: -30, right: -20, child: _blob(120, 0.18)),
            Positioned(bottom: -40, left: -30, child: _blob(150, 0.12)),
            Positioned(top: 40, left: 40, child: _blob(40, 0.10)),
            Padding(padding: padding, child: child),
          ],
        ),
      ),
    );
  }

  Widget _blob(double size, double opacity) => Container(
    width: size, height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Colors.white.withValues(alpha: opacity),
    ),
  );
}

/// A small soft icon badge with a tinted rounded-square background.
class IconBadge extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  final Gradient? gradient;

  const IconBadge({
    super.key,
    required this.icon,
    required this.color,
    this.size = 48,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        color: gradient == null ? color.withValues(alpha: 0.14) : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      child: Icon(icon, color: gradient != null ? Colors.white : color, size: size * 0.5),
    );
  }
}

/// Soft animated linear progress bar with rounded caps.
class SoftProgressBar extends StatelessWidget {
  final double value; // 0..1
  final Color? color;
  final double height;
  final Color? background;

  const SoftProgressBar({
    super.key,
    required this.value,
    this.color,
    this.height = 8,
    this.background,
  });

  @override
  Widget build(BuildContext context) {
    final color = this.color ?? AppTheme.primary;
    return LayoutBuilder(builder: (context, constraints) {
      return Container(
        height: height,
        decoration: BoxDecoration(
          color: background ?? color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(height),
        ),
        child: Align(
          alignment: Alignment.centerLeft,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 450),
            curve: Curves.easeOutCubic,
            width: constraints.maxWidth * value.clamp(0.0, 1.0),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [color.withValues(alpha: 0.85), color]),
              borderRadius: BorderRadius.circular(height),
            ),
          ),
        ),
      );
    });
  }
}

/// A friendly empty-state with a soft circular illustration backdrop.
class SoftEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Color? color;
  final Widget? action;

  const SoftEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.color,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final color = this.color ?? AppTheme.primary;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 110, height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [color.withValues(alpha: 0.18), color.withValues(alpha: 0.06)],
                ),
              ),
              child: Icon(icon, size: 52, color: color),
            ),
            const SizedBox(height: 22),
            Text(title, style: TextStyle(
              fontSize: 19, fontWeight: FontWeight.w700, color: AppTheme.ink)),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.inkSoft, height: 1.5)),
            if (action != null) ...[const SizedBox(height: 24), action!],
          ],
        ),
      ),
    );
  }
}

/// Subtle dotted/organic decorative pattern painter for calm empty spaces.
class SoftDotPattern extends StatelessWidget {
  final Color color;
  final double opacity;
  const SoftDotPattern({super.key, this.color = Colors.white, this.opacity = 0.15});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _DotPainter(color.withValues(alpha: opacity)), child: const SizedBox.expand());
  }
}

class _DotPainter extends CustomPainter {
  final Color color;
  _DotPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    const spacing = 26.0;
    for (double y = 0; y < size.height; y += spacing) {
      for (double x = 0; x < size.width; x += spacing) {
        canvas.drawCircle(Offset(x, y), 1.6, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DotPainter oldDelegate) => false;
}

/// Staggered fade+slide-in for list/grid children — adds gentle entrance motion.
class FadeSlideIn extends StatelessWidget {
  final Widget child;
  final int index;
  final Duration baseDelay;
  const FadeSlideIn({super.key, required this.child, this.index = 0, this.baseDelay = const Duration(milliseconds: 60)});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 420 + math.min(index, 8) * 70),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.translate(offset: Offset(0, (1 - t) * 18), child: child),
      ),
      child: child,
    );
  }
}

/// A compact app-bar-style gradient header: rounded bottom, decorative blobs,
/// a back button, optional leading icon, title (+ optional subtitle) and trailing
/// actions. Optionally renders a [bottom] widget (e.g. a tab selector) inside the
/// gradient. This is the premium header shared across secondary screens.
class CompactGradientHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final Gradient gradient;
  final VoidCallback? onBack;
  final IconData backIcon;
  final List<Widget> actions;
  final Widget? bottom;
  final EdgeInsetsGeometry padding;

  const CompactGradientHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.gradient = AppTheme.heroGradient,
    this.onBack,
    this.backIcon = Icons.arrow_back_rounded,
    this.actions = const [],
    this.bottom,
    this.padding = const EdgeInsets.fromLTRB(16, 12, 16, 16),
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(AppTheme.rXl)),
      child: Container(
        decoration: BoxDecoration(gradient: gradient),
        child: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              Positioned(top: -24, right: -24, child: _blob(100, 0.14)),
              Positioned(bottom: -34, left: -18, child: _blob(120, 0.10)),
              Positioned(top: 16, left: 72, child: _blob(28, 0.07)),
              Padding(
                padding: padding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(children: [
                      TapScale(
                        onTap: onBack ?? () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(12)),
                          child: Icon(backIcon, color: Colors.white, size: 20),
                        ),
                      ),
                      const SizedBox(width: 14),
                      if (icon != null) ...[
                        Icon(icon, color: Colors.white, size: 20),
                        const SizedBox(width: 10),
                      ],
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(title, style: const TextStyle(
                              color: Colors.white, fontSize: 20,
                              fontWeight: FontWeight.w800, letterSpacing: -0.4)),
                            if (subtitle != null)
                              Text(subtitle!, style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.82), fontSize: 12.5)),
                          ],
                        ),
                      ),
                      ...actions,
                    ]),
                    if (bottom != null) ...[
                      const SizedBox(height: 14),
                      bottom!,
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _blob(double size, double opacity) => Container(
    width: size, height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle, color: Colors.white.withValues(alpha: opacity)),
  );
}
