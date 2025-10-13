import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'services/firestore_service.dart';
import 'services/api_service.dart';
import 'services/settings_service.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'screens/home/home_screen.dart';

class ThemeNotifier with ChangeNotifier {
  bool _isDarkMode = false;

  bool get isDarkMode => _isDarkMode;

  void setDarkMode(bool value) {
    _isDarkMode = value;
    notifyListeners();
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicialização segura do Firebase com tratamento de erros
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    print('⚠️ Firebase não configurado: $e');
    print('ℹ️ Execute: flutterfire configure');
    print('ℹ️ Para execução local sem Firebase, modifique este arquivo');

    // Para desenvolvimento local sem Firebase configurado:
    // await Firebase.initializeApp();

    throw Exception('Firebase não configurado. Siga as instruções no README.md');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // Elegant Book-Inspired Color Palette
  static const ColorScheme _lightColorScheme = ColorScheme(
    primary: Color(0xFF8D6E63),        // Antique Brown
    secondary: Color(0xFFD7CCC8),      // Light Beige
    surface: Color(0xFFFAFAFA),        // Clean White
    background: Color(0xFFFFFBF7),     // Warm Cream
    error: Color(0xFFBCAAA4),         // Soft Error
    onPrimary: Color(0xFFFFFFFF),      // White on Antique Brown
    onSecondary: Color(0xFF3E2723),    // Dark Brown on Beige
    onSurface: Color(0xFF3E2723),      // Dark Brown Text
    onBackground: Color(0xFF3E2723),   // Dark Brown Background Text
    onError: Color(0xFFFFFFFF),        // White on Error
    brightness: Brightness.light,
  );

  static const ColorScheme _darkColorScheme = ColorScheme(
    primary: Color(0xFFB39DDB),        // Light Purple
    secondary: Color(0xFF6D4C41),      // Dark Brown
    surface: Color(0xFF1E1E1E),        // Dark Surface
    background: Color(0xFF121212),     // Dark Background
    error: Color(0xFFCF6679),          // Dark Error
    onPrimary: Color(0xFF1E1E1E),      // Dark Text on Light Purple
    onSecondary: Color(0xFFE8EAF6),    // Light Text on Dark Brown
    onSurface: Color(0xFFE8EAF6),      // Light Text on Dark Surface
    onBackground: Color(0xFFE8EAF6),   // Light Text on Dark Background
    onError: Color(0xFF1E1E1E),        // Dark Text on Error
    brightness: Brightness.dark,
  );

  static ThemeData _buildElegantTheme(bool isDark) {
    final colorScheme = isDark ? _darkColorScheme : _lightColorScheme;

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      fontFamily: GoogleFonts.crimsonText().fontFamily,
      scaffoldBackgroundColor: colorScheme.background,

      // Elegant Typography with Serif Fonts
      textTheme: GoogleFonts.crimsonTextTextTheme().copyWith(
        headlineLarge: GoogleFonts.crimsonText(
          fontSize: 32,
          fontWeight: FontWeight.w400,
          height: 1.2,
          color: colorScheme.onBackground,
        ),
        headlineMedium: GoogleFonts.crimsonText(
          fontSize: 28,
          fontWeight: FontWeight.w400,
          height: 1.25,
          color: colorScheme.onBackground,
        ),
        headlineSmall: GoogleFonts.crimsonText(
          fontSize: 24,
          fontWeight: FontWeight.w500,
          height: 1.3,
          color: colorScheme.onBackground,
        ),
        titleLarge: GoogleFonts.libreBaskerville(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          height: 1.35,
          color: colorScheme.onSurface,
        ),
        titleMedium: GoogleFonts.libreBaskerville(
          fontSize: 18,
          fontWeight: FontWeight.w500,
          height: 1.4,
          color: colorScheme.onSurface,
        ),
        titleSmall: GoogleFonts.libreBaskerville(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          height: 1.4,
          color: colorScheme.onSurfaceVariant,
        ),
        bodyLarge: GoogleFonts.libreBaskerville(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          height: 1.5,
          color: colorScheme.onSurface,
        ),
        bodyMedium: GoogleFonts.libreBaskerville(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          height: 1.5,
          color: colorScheme.onSurfaceVariant,
        ),
        bodySmall: GoogleFonts.libreFranklin(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          height: 1.5,
          color: colorScheme.onSurfaceVariant,
        ),
      ),

      // AppBar with Elegant Design
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.crimsonText(
          fontSize: 24,
          fontWeight: FontWeight.w500,
          color: colorScheme.onSurface,
        ),
        iconTheme: IconThemeData(
          color: colorScheme.onSurfaceVariant,
        ),
      ),

      // Elevated Buttons with Book-inspired Design
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
          shadowColor: colorScheme.shadow,
          textStyle: GoogleFonts.libreFranklin(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),

      // Input Decoration with Elegant Borders
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceVariant.withOpacity(0.3),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: colorScheme.primary,
            width: 2,
          ),
        ),
        labelStyle: GoogleFonts.libreFranklin(
          color: colorScheme.onSurfaceVariant,
        ),
        hintStyle: GoogleFonts.libreFranklin(
          color: colorScheme.onSurfaceVariant.withOpacity(0.7),
        ),
      ),

      // Card Design Inspired by Bookmarks
      cardTheme: CardThemeData(
        color: colorScheme.surface,
        elevation: 2,
        shadowColor: colorScheme.shadow.withOpacity(0.3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        margin: const EdgeInsets.only(bottom: 12),
      ),

      // FAB with Bookmark-like Design
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: 4,
      ),

      // Page Transitions with Book Flipping Animation
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
        },
      ),

      // Snackbar with Elegant Design
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colorScheme.secondaryContainer,
        contentTextStyle: GoogleFonts.libreFranklin(
          color: colorScheme.onSecondaryContainer,
          fontSize: 14,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        behavior: SnackBarBehavior.floating,
      ),

      // ListTile with Elegant Spacing
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        titleTextStyle: GoogleFonts.libreBaskerville(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: colorScheme.onSurface,
        ),
        subtitleTextStyle: GoogleFonts.libreFranklin(
          fontSize: 14,
          color: colorScheme.onSurfaceVariant,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ThemeNotifier(),
      child: Consumer<ThemeNotifier>(
        builder: (context, themeNotifier, child) =>
          MultiProvider(
            providers: [
              Provider<AuthService>(
                create: (_) => AuthService(),
              ),
              Provider<FirestoreService>(
                create: (_) => FirestoreService(),
              ),
              Provider<ApiService>(
                create: (_) => ApiService(),
              ),
              Provider<SettingsService>(
                create: (_) => SettingsService(),
              ),
            ],
            child: MaterialApp(
              title: 'Onde Parei?',
              debugShowCheckedModeBanner: false,
              theme: _buildElegantTheme(false),
              darkTheme: _buildElegantTheme(true),
              themeMode: themeNotifier.isDarkMode ? ThemeMode.dark : ThemeMode.light,
              home: const AuthWrapper(),
              routes: {
                '/login': (context) => const LoginScreen(),
                '/signup': (context) => const SignupScreen(),
                '/home': (context) => const HomeScreen(),
              },
            ),
          ),
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);

    return StreamBuilder(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.active) {
          final user = snapshot.data;

          if (user == null) {
            return const LoginScreen();
          } else {
            return const HomeScreen();
          }
        }

        // Loading screen
        return const Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        );
      },
    );
  }
}
