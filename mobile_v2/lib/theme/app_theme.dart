import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Визуальный язык v3: глубокий изумруд + океанский градиент,
/// заголовки Manrope, текст Inter, крупные радиусы, «мягкие» поверхности.
class AppTheme {
  static const Color brandEmerald = Color(0xFF0F8A6D);
  static const Color brandOcean = Color(0xFF0E6E8C);
  static const Color brandMint = Color(0xFF7BE0C3);

  static const double radiusCard = 24.0;
  static const double radiusField = 16.0;
  static const double radiusDialog = 28.0;

  /// Фирменный градиент для hero-блоков, аватаров и акцентов.
  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [brandEmerald, brandOcean],
  );

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final bool isDark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: brandEmerald,
      brightness: brightness,
    ).copyWith(
      primary: isDark ? brandMint : brandEmerald,
      tertiary: brandOcean,
      surface: isDark ? const Color(0xFF101614) : const Color(0xFFF7FAF8),
    );

    final base = ThemeData(brightness: brightness, colorScheme: scheme, useMaterial3: true);

    final headingColor = scheme.onSurface;
    final textTheme = GoogleFonts.interTextTheme(base.textTheme).copyWith(
      displaySmall: GoogleFonts.manrope(fontSize: 34, fontWeight: FontWeight.w800, color: headingColor, height: 1.15),
      headlineMedium: GoogleFonts.manrope(fontSize: 26, fontWeight: FontWeight.w800, color: headingColor, height: 1.2),
      titleLarge: GoogleFonts.manrope(fontSize: 22, fontWeight: FontWeight.w800, color: headingColor),
      titleMedium: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.w700, color: headingColor),
      titleSmall: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w700, color: headingColor),
      bodyLarge: GoogleFonts.inter(fontSize: 15, height: 1.45, color: scheme.onSurface),
      bodyMedium: GoogleFonts.inter(fontSize: 14, height: 1.45, color: scheme.onSurface),
      bodySmall: GoogleFonts.inter(fontSize: 12, height: 1.4, color: scheme.onSurfaceVariant),
      labelLarge: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
    );

    return base.copyWith(
      scaffoldBackgroundColor: scheme.surface,
      textTheme: textTheme,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
      ),
      cardTheme: CardTheme(
        elevation: 0,
        color: isDark ? scheme.surfaceContainerLow : Colors.white,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusCard),
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: isDark ? 0.25 : 0.45)),
        ),
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: const StadiumBorder(),
          textStyle: GoogleFonts.manrope(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: const StadiumBorder(),
          textStyle: GoogleFonts.manrope(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: const StadiumBorder(),
          side: BorderSide(color: scheme.outlineVariant),
          textStyle: GoogleFonts.manrope(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: const StadiumBorder(),
          textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark
            ? scheme.surfaceContainerHigh.withValues(alpha: 0.5)
            : scheme.surfaceContainerHighest.withValues(alpha: 0.45),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusField),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusField),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusField),
          borderSide: BorderSide(color: scheme.primary, width: 1.6),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.transparent,
        elevation: 0,
        indicatorColor: scheme.primary.withValues(alpha: isDark ? 0.22 : 0.14),
        indicatorShape: const StadiumBorder(),
        height: 68,
        labelTextStyle: WidgetStatePropertyAll(
          GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected) ? scheme.primary : scheme.onSurfaceVariant,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        labelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
        side: BorderSide.none,
      ),
      dialogTheme: DialogTheme(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusDialog)),
        backgroundColor: scheme.surfaceContainerLow,
        titleTextStyle: textTheme.titleLarge,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(radiusDialog)),
        ),
        showDragHandle: true,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusField)),
        backgroundColor: isDark ? scheme.surfaceContainerHighest : const Color(0xFF1E2B27),
        contentTextStyle: GoogleFonts.inter(fontSize: 14, color: Colors.white),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusField)),
        titleTextStyle: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
        subtitleTextStyle: textTheme.bodySmall,
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: 0.3),
        thickness: 1,
        space: 1,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: scheme.primary),
      tabBarTheme: TabBarTheme(
        labelStyle: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w700),
        unselectedLabelStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500),
        indicatorSize: TabBarIndicatorSize.label,
      ),
    );
  }

  static Color severityColor(BuildContext context, String severity) {
    final scheme = Theme.of(context).colorScheme;
    return switch (severity.toUpperCase()) {
      'CRITICAL' => scheme.error,
      'WARNING' => const Color(0xFFD97706),
      'INFO' => scheme.primary,
      _ => scheme.outline,
    };
  }

  static String severityLabel(String severity) {
    return switch (severity.toUpperCase()) {
      'CRITICAL' => 'Высокий',
      'WARNING' => 'Средний',
      'INFO' => 'Низкий',
      _ => severity,
    };
  }

  /// Цвет уровня риска аналитики (LOW / MEDIUM / HIGH).
  static Color riskColor(BuildContext context, String? level) {
    final scheme = Theme.of(context).colorScheme;
    return switch ((level ?? '').toUpperCase()) {
      'HIGH' => scheme.error,
      'MEDIUM' => const Color(0xFFD97706),
      'LOW' => brandEmerald,
      _ => scheme.outline,
    };
  }
}
