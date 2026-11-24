import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';

/// Beszel-like dark palette: near-black neutrals, hairline borders,
/// colour reserved for status and charts.
class Bz {
  static const bg = Color(0xFF0B0C0E);
  static const card = Color(0xFF131418);
  static const cardTop = Color(0xFF191A20); // gradient start
  static const cardHi = Color(0xFF1F2125);
  static const border = Color(0xFF272A2F);
  static const text = Color(0xFFF4F4F5);
  static const muted = Color(0xFF8B909A);
  static const track = Color(0xFF272A2F);

  static const accent = Color(0xFF60A5FA); // blue
  static const green = Color(0xFF34D399);
  static const orange = Color(0xFFFB923C);
  static const red = Color(0xFFF87171);
  static const purple = Color(0xFFA78BFA);
  static const teal = Color(0xFF2DD4BF);

  static Color status(String s) => switch (s) {
        'up' => green,
        'down' => red,
        _ => muted,
      };

  /// Color for a 0-100 load value.
  static Color load(double v) => v >= 90 ? red : v >= 70 ? orange : accent;
}

ThemeData beszelTheme() {
  final cs = ColorScheme.fromSeed(seedColor: Bz.accent, brightness: Brightness.dark).copyWith(
    primary: Bz.accent,
    onPrimary: Bz.bg,
    secondary: Bz.accent,
    tertiary: Bz.green,
    error: Bz.red,
    surface: Bz.bg,
    onSurface: Bz.text,
    surfaceContainerHigh: Bz.card,
    surfaceContainerHighest: Bz.cardHi,
    onSurfaceVariant: Bz.muted,
    outline: Bz.border,
    outlineVariant: Bz.border,
  );
  const radius = 14.0;
  OutlineInputBorder outline(Color c, [double w = 1]) =>
      OutlineInputBorder(borderRadius: BorderRadius.circular(radius), borderSide: BorderSide(color: c, width: w));
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: cs,
    scaffoldBackgroundColor: Bz.bg,
    appBarTheme: const AppBarTheme(
      backgroundColor: Bz.bg,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      centerTitle: false,
      toolbarHeight: 68,
      titleSpacing: 20,
      titleTextStyle: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Bz.text, letterSpacing: -1),
    ),
    dividerTheme: const DividerThemeData(color: Bz.border, space: 1),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Bz.card,
      border: outline(Bz.border),
      enabledBorder: outline(Bz.border),
      focusedBorder: outline(Bz.muted, 1.5),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: Bz.text,
        foregroundColor: Bz.bg,
        shape: const StadiumBorder(),
        minimumSize: const Size.fromHeight(52),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Colors.transparent,
      selectedColor: Bz.cardHi,
      side: const BorderSide(color: Bz.border),
      showCheckmark: false,
      labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Bz.text),
      shape: const StadiumBorder(),
      padding: const EdgeInsets.symmetric(horizontal: 6),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Bz.bg : Bz.muted),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Bz.text : Bz.track),
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
    ),
    sliderTheme: const SliderThemeData(
      activeTrackColor: Bz.text,
      thumbColor: Bz.text,
      inactiveTrackColor: Bz.track,
      overlayColor: Color(0x1FF4F4F5),
    ),
  );
}

/// Flat card with a hairline border. [accent] tints the border to flag a
/// problem (e.g. a device that is down).
class BzCard extends StatelessWidget {
  final Widget child;
  final Color? accent;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  const BzCard({
    super.key,
    required this.child,
    this.accent,
    this.onTap,
    this.padding = const EdgeInsets.all(18),
    this.margin = const EdgeInsets.only(bottom: 12),
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(22);
    final top = accent == null ? Bz.cardTop : Color.alphaBlend(accent!.withValues(alpha: 0.10), Bz.cardTop);
    // Frosted glass: translucent fill over a mild blur of whatever is behind.
    return Padding(
      padding: margin,
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: radius,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [top.withValues(alpha: 0.72), Bz.card.withValues(alpha: 0.62)],
              ),
              border: Border.all(color: accent?.withValues(alpha: 0.45) ?? Colors.white.withValues(alpha: 0.07)),
            ),
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                borderRadius: radius,
                onTap: onTap,
                child: Padding(padding: padding, child: child),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Fixed, very faint colour glows behind the content so the glass cards have
/// something to blur. Kept subtle on purpose.
class AmbientBackground extends StatelessWidget {
  final Widget child;
  const AmbientBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    Widget glow(Color c, Alignment a) => Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(center: a, radius: 0.9, colors: [c.withValues(alpha: 0.13), c.withValues(alpha: 0)]),
            ),
          ),
        );
    return Stack(children: [
      glow(Bz.accent, const Alignment(1.1, -1.0)),
      glow(Bz.purple, const Alignment(-1.2, 0.9)),
      child,
    ]);
  }
}

/// Tinted rounded label, e.g. "Online".
class Pill extends StatelessWidget {
  final String text;
  final Color color;
  const Pill(this.text, this.color, {super.key});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          StatusDot(color, size: 6),
          const SizedBox(width: 6),
          Text(text, style: TextStyle(color: color, fontSize: 11.5, fontWeight: FontWeight.w700)),
        ]),
      );
}

/// Plain status dot.
class StatusDot extends StatelessWidget {
  final Color color;
  final double size;
  const StatusDot(this.color, {super.key, this.size = 10});

  @override
  Widget build(BuildContext context) => Container(width: size, height: size, decoration: BoxDecoration(color: color, shape: BoxShape.circle));
}
