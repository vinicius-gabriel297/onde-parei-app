import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Paleta "Biblioteca Clássica": couro envelhecido, papel creme, ouro velho
/// e verde-musgo. Os tokens abaixo são os únicos valores de cor usados no app.
abstract final class AppColors {
  // Marca
  static const gold = Color(0xFFD3AC63);
  static const goldDeep = Color(0xFF8A5A26);
  static const moss = Color(0xFF6E9068);
  static const mossDeep = Color(0xFF3F5C39);
  static const terracotta = Color(0xFFC07A4E);
  static const ink = Color(0xFF1B150F);
  static const paper = Color(0xFFFBF5E7);

  // Status de leitura
  static const statusReading = Color(0xFFD3AC63);
  static const statusRead = Color(0xFF6E9068);
  static const statusWant = Color(0xFF6E8F9E);

  // Tipos de obra
  static const typeBook = Color(0xFF6E9068);
  static const typeManga = Color(0xFF6E8F9E);
  static const typeManhwa = Color(0xFFC07A4E);
  static const typeManhua = Color(0xFFA06E9E);

  static Color forType(String type) {
    switch (type) {
      case 'manga':
        return typeManga;
      case 'manhwa':
        return typeManhwa;
      case 'manhua':
        return typeManhua;
      default:
        return typeBook;
    }
  }
}

abstract final class AppRadius {
  static const sm = 10.0;
  static const md = 14.0;
  static const lg = 20.0;
  static const pill = 999.0;
}

class AppTheme {
  static const ColorScheme _light = ColorScheme(
    brightness: Brightness.light,
    primary: AppColors.goldDeep,
    onPrimary: Color(0xFFFFF8EA),
    primaryContainer: Color(0xFFF0DCB8),
    onPrimaryContainer: Color(0xFF3A2409),
    secondary: AppColors.mossDeep,
    onSecondary: Color(0xFFF3F7EF),
    secondaryContainer: Color(0xFFDCE7D4),
    onSecondaryContainer: Color(0xFF1D2A19),
    tertiary: Color(0xFF9A5A32),
    onTertiary: Color(0xFFFFF3EA),
    error: Color(0xFF9B2C2C),
    onError: Color(0xFFFFF1F1),
    surface: AppColors.paper,
    onSurface: Color(0xFF211A12),
    surfaceContainerLowest: Color(0xFFFFFCF4),
    surfaceContainerLow: Color(0xFFF7EFDD),
    surfaceContainer: Color(0xFFF2E8D2),
    surfaceContainerHigh: Color(0xFFEDE1C7),
    surfaceContainerHighest: Color(0xFFE7D9BB),
    onSurfaceVariant: Color(0xFF6B573C),
    outline: Color(0xFFB9A583),
    outlineVariant: Color(0xFFDCCCA9),
    inverseSurface: Color(0xFF322A20),
    onInverseSurface: Color(0xFFF6EEDC),
    shadow: Color(0x33000000),
    scrim: Color(0x99000000),
  );

  static const ColorScheme _dark = ColorScheme(
    brightness: Brightness.dark,
    primary: AppColors.gold,
    onPrimary: Color(0xFF1B150F),
    primaryContainer: Color(0xFF4A3418),
    onPrimaryContainer: Color(0xFFF6E4BE),
    secondary: AppColors.moss,
    onSecondary: Color(0xFF10180E),
    secondaryContainer: Color(0xFF2C3D28),
    onSecondaryContainer: Color(0xFFD6E6D0),
    tertiary: AppColors.terracotta,
    onTertiary: Color(0xFF23120A),
    error: Color(0xFFE2716B),
    onError: Color(0xFF2A0E0C),
    surface: Color(0xFF14100B),
    onSurface: Color(0xFFF2E9D6),
    surfaceContainerLowest: Color(0xFF0F0C08),
    surfaceContainerLow: Color(0xFF1A1510),
    surfaceContainer: Color(0xFF211A13),
    surfaceContainerHigh: Color(0xFF2A2118),
    surfaceContainerHighest: Color(0xFF34291D),
    onSurfaceVariant: Color(0xFFC0AC8D),
    outline: Color(0xFF57493A),
    outlineVariant: Color(0xFF3A3026),
    inverseSurface: Color(0xFFF2E9D6),
    onInverseSurface: Color(0xFF1B150F),
    shadow: Color(0x66000000),
    scrim: Color(0xCC000000),
  );

  static ThemeData light() => _build(_light);
  static ThemeData dark() => _build(_dark);

  static ThemeData _build(ColorScheme scheme) {
    final isDark = scheme.brightness == Brightness.dark;

    final display = GoogleFonts.crimsonText;
    final serif = GoogleFonts.libreBaskerville;
    final sans = GoogleFonts.libreFranklin;

    final textTheme = TextTheme(
      displaySmall: display(
        fontSize: 34,
        fontWeight: FontWeight.w600,
        height: 1.15,
        color: scheme.onSurface,
      ),
      headlineMedium: display(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        height: 1.2,
        color: scheme.onSurface,
      ),
      headlineSmall: display(
        fontSize: 23,
        fontWeight: FontWeight.w600,
        height: 1.25,
        color: scheme.onSurface,
      ),
      titleLarge: display(
        fontSize: 21,
        fontWeight: FontWeight.w600,
        height: 1.3,
        color: scheme.onSurface,
      ),
      titleMedium: serif(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: 1.35,
        color: scheme.onSurface,
      ),
      titleSmall: sans(
        fontSize: 13.5,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
        color: scheme.onSurfaceVariant,
      ),
      bodyLarge: serif(
        fontSize: 15.5,
        height: 1.55,
        color: scheme.onSurface,
      ),
      bodyMedium: sans(
        fontSize: 14,
        height: 1.5,
        color: scheme.onSurfaceVariant,
      ),
      bodySmall: sans(
        fontSize: 12.5,
        height: 1.45,
        color: scheme.onSurfaceVariant,
      ),
      labelLarge: sans(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
      ),
      labelMedium: sans(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.3,
      ),
      labelSmall: sans(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.4,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      textTheme: textTheme,
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,

      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: display(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
        iconTheme: IconThemeData(color: scheme.onSurface, size: 22),
        systemOverlayStyle: isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
      ),

      cardTheme: CardThemeData(
        color: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          disabledBackgroundColor: scheme.onSurface.withValues(alpha: 0.12),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.primary,
          side: BorderSide(color: scheme.outline),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          textStyle: textTheme.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainer,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: scheme.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: scheme.error),
        ),
        labelStyle: sans(fontSize: 14, color: scheme.onSurfaceVariant),
        floatingLabelStyle: sans(fontSize: 14, color: scheme.primary),
        hintStyle: sans(
          fontSize: 14,
          color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
        ),
        prefixIconColor: scheme.onSurfaceVariant,
        suffixIconColor: scheme.onSurfaceVariant,
      ),

      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainer,
        selectedColor: scheme.primaryContainer,
        side: BorderSide(color: scheme.outlineVariant),
        labelStyle: sans(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: scheme.onSurface,
        ),
        secondaryLabelStyle: sans(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: scheme.onPrimaryContainer,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: const StadiumBorder(),
        showCheckmark: false,
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primary.withValues(alpha: 0.18),
        elevation: 0,
        height: 66,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => sans(
            fontSize: 11.5,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w600
                : FontWeight.w500,
            color: states.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.onSurfaceVariant,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 23,
            color: states.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.onSurfaceVariant,
          ),
        ),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium,
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.lg),
          ),
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: sans(
          fontSize: 13.5,
          color: scheme.onInverseSurface,
        ),
        actionTextColor: scheme.primary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        behavior: SnackBarBehavior.floating,
        insetPadding: const EdgeInsets.all(16),
      ),

      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        titleTextStyle: textTheme.titleMedium,
        subtitleTextStyle: textTheme.bodySmall,
        iconColor: scheme.onSurfaceVariant,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),

      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.surfaceContainerHigh,
        circularTrackColor: scheme.surfaceContainerHigh,
      ),

      popupMenuTheme: PopupMenuThemeData(
        color: scheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        textStyle: textTheme.bodyMedium?.copyWith(color: scheme.onSurface),
      ),

      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: scheme.inverseSurface,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        textStyle: sans(fontSize: 12, color: scheme.onInverseSurface),
      ),

      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
        },
      ),
    );
  }
}
