import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// M MUSIC — RED & BLACK GLASSMORPHISM palette.
abstract final class MColors {
  static const Color background = Color(0xFF080808);
  static const Color surface = Color(0xFF120809);
  static const Color darkRed = Color(0xFF450000);
  static const Color primary = Color(0xFFFF1028);
  static const Color bright = Color(0xFFFF3045);
  static const Color text = Color(0xFFFFFFFF);
  static const Color muted = Color(0xFFA5A5A5);
  static const Color glassTint = Color(0x12FF1028);
  static const Color glassBorder = Color(0x3DFF1028);

  static LinearGradient get redGradient => const LinearGradient(
        colors: [primary, bright, darkRed],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  static LinearGradient get glassGradient => LinearGradient(
        colors: [
          Colors.white.withOpacity(0.06),
          const Color(0x0AFF1028),
          Colors.black.withOpacity(0.18),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
}

class MTheme {
  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: MColors.background,
        canvasColor: MColors.surface,
        colorScheme: const ColorScheme.dark(
          primary: MColors.primary,
          secondary: MColors.bright,
          surface: MColors.surface,
          error: MColors.bright,
          onPrimary: Colors.white,
          onSurface: MColors.text,
        ),
        textTheme: const TextTheme(
          displayLarge: TextStyle(color: MColors.text, fontWeight: FontWeight.w900, letterSpacing: -1),
          displayMedium: TextStyle(color: MColors.text, fontWeight: FontWeight.w800, letterSpacing: -0.5),
          headlineMedium: TextStyle(color: MColors.text, fontWeight: FontWeight.w700),
          titleLarge: TextStyle(color: MColors.text, fontWeight: FontWeight.w700),
          titleMedium: TextStyle(color: MColors.text, fontWeight: FontWeight.w600),
          bodyLarge: TextStyle(color: MColors.text),
          bodyMedium: TextStyle(color: MColors.text),
          bodySmall: TextStyle(color: MColors.muted),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: MColors.text,
          titleTextStyle: TextStyle(color: MColors.text, fontSize: 18, fontWeight: FontWeight.w800),
        ),
        iconTheme: const IconThemeData(color: MColors.text),
        dividerTheme: DividerThemeData(color: MColors.primary.withOpacity(0.16), space: 1),
        cardTheme: CardThemeData(
          color: MColors.glassTint,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: MColors.glassBorder, width: 1),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white.withOpacity(0.05),
          hintStyle: const TextStyle(color: MColors.muted),
          prefixIconColor: MColors.muted,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: MColors.glassBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: MColors.primary, width: 1.6),
          ),
        ),
        navigationRailTheme: NavigationRailThemeData(
          backgroundColor: Colors.transparent,
          selectedIconTheme: const IconThemeData(color: Colors.white),
          unselectedIconTheme: const IconThemeData(color: MColors.muted),
          selectedLabelTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          unselectedLabelTextStyle: const TextStyle(color: MColors.muted),
          indicatorColor: MColors.primary.withOpacity(0.22),
        ),
        sliderTheme: SliderThemeData(
          activeTrackColor: MColors.primary,
          inactiveTrackColor: Colors.white.withOpacity(0.12),
          thumbColor: MColors.bright,
          overlayColor: MColors.primary.withOpacity(0.2),
        ),
        tooltipTheme: TooltipThemeData(
          decoration: BoxDecoration(
            color: MColors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: MColors.glassBorder),
          ),
          textStyle: const TextStyle(color: MColors.text, fontSize: 12),
        ),
      );
}

/// Animated red smoke / light backdrop. Repaints at ~30fps and uses no images.
class AnimatedRedBackdrop extends StatefulWidget {
  const AnimatedRedBackdrop({super.key, this.child, this.intensity = 1.0});

  final Widget? child;
  final double intensity;

  @override
  State<AnimatedRedBackdrop> createState() => _AnimatedRedBackdropState();
}

class _AnimatedRedBackdropState extends State<AnimatedRedBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 18),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        AnimatedBuilder(
          animation: _c,
          builder: (_, __) => CustomPaint(
            painter: _SmokePainter(_c.value, widget.intensity),
          ),
        ),
        if (widget.child != null) widget.child!,
      ],
    );
  }
}

class _SmokePainter extends CustomPainter {
  _SmokePainter(this.t, this.intensity);

  final double t;
  final double intensity;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = MColors.background);

    final blobs = <_Blob>[
      _Blob(0.18, 0.22, 0.55, 0.20, MColors.primary),
      _Blob(0.82, 0.30, 0.50, 0.17, MColors.darkRed),
      _Blob(0.62, 0.86, 0.62, 0.18, MColors.bright),
      _Blob(0.08, 0.78, 0.40, 0.14, MColors.primary),
    ];

    for (var i = 0; i < blobs.length; i++) {
      final b = blobs[i];
      final phase = t * math.pi * 2 + i * 1.7;
      final cx = size.width * (b.x + 0.06 * math.sin(phase));
      final cy = size.height * (b.y + 0.07 * math.cos(phase * 0.8));
      final r = math.max(size.width, size.height) * b.radius;
      final rect = Rect.fromCircle(center: Offset(cx, cy), radius: r);
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            b.color.withOpacity(0.16 * intensity),
            b.color.withOpacity(0.05 * intensity),
            Colors.transparent,
          ],
          stops: const [0.0, 0.45, 1.0],
        ).createShader(rect);
      canvas.drawCircle(Offset(cx, cy), r, paint);
    }

    final veil = Paint()
      ..shader = const LinearGradient(
        colors: [Colors.transparent, Color(0x08000000), Colors.transparent],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, veil);
  }

  @override
  bool shouldRepaint(covariant _SmokePainter old) => old.t != t || old.intensity != intensity;
}

class _Blob {
  const _Blob(this.x, this.y, this.radius, this.opacity, this.color);

  final double x;
  final double y;
  final double radius;
  final double opacity;
  final Color color;
}

/// Frosted red-glass container used across the whole app.
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin = EdgeInsets.zero,
    this.radius = 18,
    this.blur = 18,
    this.border = true,
    this.glow = false,
    this.onTap,
    this.color,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final double radius;
  final double blur;
  final bool border;
  final bool glow;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    Widget box = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: color ?? MColors.glassTint,
            gradient: color == null ? MColors.glassGradient : null,
            borderRadius: BorderRadius.circular(radius),
            border: border
                ? Border.all(color: MColors.primary.withOpacity(glow ? 0.55 : 0.22))
                : null,
            boxShadow: glow
                ? [
                    BoxShadow(
                      color: MColors.primary.withOpacity(0.28),
                      blurRadius: 26,
                      spreadRadius: 1,
                    )
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.35),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    )
                  ],
          ),
          child: child,
        ),
      ),
    );
    if (onTap != null) {
      box = Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(radius),
          onTap: onTap,
          child: box,
        ),
      );
    }
    return Padding(padding: margin, child: box);
  }
}

/// Rounded red action button with a real press effect.
class GlowButton extends StatelessWidget {
  const GlowButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.filled = false,
    this.compact = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool filled;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final fg = filled ? Colors.white : MColors.bright;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(compact ? 22 : 14),
        onTap: onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 14 : 22,
            vertical: compact ? 9 : 13,
          ),
          decoration: BoxDecoration(
            gradient: filled ? MColors.redGradient : null,
            color: filled ? null : MColors.primary.withOpacity(0.10),
            borderRadius: BorderRadius.circular(compact ? 22 : 14),
            border: Border.all(color: MColors.primary.withOpacity(filled ? 0 : 0.5)),
            boxShadow: filled
                ? [BoxShadow(color: MColors.primary.withOpacity(0.35), blurRadius: 20)]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: fg, size: compact ? 16 : 18),
              if (label.isNotEmpty) ...[
                SizedBox(width: compact ? 6 : 10),
                Text(
                  label,
                  style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: compact ? 12 : 14),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The app mark — circular neon M, generated asset with a text fallback.
class MLogo extends StatelessWidget {
  const MLogo({super.key, this.size = 34, this.showGlow = true});

  final double size;
  final bool showGlow;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: showGlow
            ? [BoxShadow(color: MColors.primary.withOpacity(0.55), blurRadius: 14)]
            : null,
      ),
      child: ClipOval(
        child: Image.asset(
          'assets/logo.png',
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            color: MColors.darkRed,
            alignment: Alignment.center,
            child: Text(
              'M',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: size * 0.6),
            ),
          ),
        ),
      ),
    );
  }
}

/// Red-glass toast used for every user-visible action.
abstract final class MToast {
  static void show(BuildContext context, String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          backgroundColor: const Color(0xEE120809),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: MColors.primary.withOpacity(0.5)),
          ),
          content: Row(
            children: [
              const Icon(Icons.graphic_eq, color: MColors.primary, size: 18),
              const SizedBox(width: 10),
              Expanded(child: Text(message, style: const TextStyle(color: Colors.white))),
            ],
          ),
        ),
      );
  }
}

/// Small uppercase label used above sections and in panels.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 3, height: 16, decoration: BoxDecoration(
          color: MColors.primary,
          borderRadius: BorderRadius.circular(3),
          boxShadow: [BoxShadow(color: MColors.primary.withOpacity(0.6), blurRadius: 8)],
        )),
        const SizedBox(width: 9),
        Text(
          text.toUpperCase(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.6,
          ),
        ),
        const Spacer(),
        if (trailing != null) trailing!,
      ],
    );
  }
}
