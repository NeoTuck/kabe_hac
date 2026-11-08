import 'package:flutter/material.dart';

class RehberTheme {
  static const ink = Color(0xFF133F3B);
  static const emerald = Color(0xFF14665C);
  static const deepEmerald = Color(0xFF0D2823);
  static const midnightSky = Color(0xFF0D1826);
  static const gold = Color(0xFFD4AF37);
  static const goldLight = Color(0xFFF7E9B8);
  static const goldDark = Color(0xFFA9801A);
  static const canvas = Color(0xFFF8F7F2);
  static const sand = Color(0xFFFAF7EE);
  static const cardDark = Color(0xFF142421);

  static const LinearGradient welcomeGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0C241F), Color(0xFF133F3B), Color(0xFF0D1B2A)],
  );

  static const LinearGradient hajjCardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF183B36), Color(0xFF0E221F)],
  );

  static const LinearGradient umrahCardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1A473F), Color(0xFF102D28)],
  );

  static ThemeData build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final colors = ColorScheme.fromSeed(
      seedColor: emerald,
      brightness: brightness,
    );
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
    );
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'NotoSans',
      fontFamilyFallback: const ['NotoNaskhArabic'],
      brightness: brightness,
      colorScheme: colors,
      scaffoldBackgroundColor: dark ? const Color(0xFF101C1A) : canvas,
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      appBarTheme: AppBarTheme(
        backgroundColor: dark ? const Color(0xFF101C1A) : canvas,
        foregroundColor: dark ? colors.onSurface : ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: 'NotoSans',
          color: dark ? colors.onSurface : ink,
          fontSize: 19,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: shape.copyWith(side: BorderSide(color: colors.outlineVariant)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 56),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontFamily: 'NotoSans',
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 56),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.all(18),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        elevation: 3,
        indicatorColor: dark
            ? const Color(0xFF1B3D36)
            : const Color(0xFFD6EDE6),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontFamily: 'NotoSans',
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected
                ? (dark ? goldLight : emerald)
                : (dark ? Colors.white60 : Colors.black54),
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected
                ? (dark ? goldLight : emerald)
                : (dark ? Colors.white60 : Colors.black54),
            size: 24,
          );
        }),
      ),
      dividerTheme: DividerThemeData(color: colors.outlineVariant, space: 32),
    );
  }
}

class FeatureStatusCard extends StatelessWidget {
  const FeatureStatusCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.action,
  });
  final IconData icon;
  final String title;
  final String description;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Card.filled(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Icon(
              icon,
              size: 32,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(description),
          if (action != null) ...[const SizedBox(height: 16), action!],
        ],
      ),
    ),
  );
}
