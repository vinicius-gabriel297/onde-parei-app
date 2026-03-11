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
  bool _isDarkMode = true; // Biblioteca Clássica — dark mode por padrão

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

    throw Exception(
      'Firebase não configurado. Siga as instruções no README.md',
    );
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // Paleta Biblioteca Clássica — couro envelhecido, papel creme, verde-musgo
  static const ColorScheme _lightColorScheme = ColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFF7A4E1F), // couro marrom
    onPrimary: Color(0xFFF5EDD6),
    secondary: Color(0xFF3D5C36), // verde-musgo profundo
    onSecondary: Color(0xFFF5EDD6),
    error: Color(0xFF9E2B2B),
    onError: Color(0xFFF5EDD6),
    surface: Color(0xFFF5EDD6), // papel creme
    onSurface: Color(0xFF1A1410),
    surfaceContainerHighest: Color(0xFFEDE0C0), // cartão claro
    onSurfaceVariant: Color(0xFF5C4A32),
  );

  static const ColorScheme _darkColorScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFFC8A45A), // ouro envelhecido / dourado
    onPrimary: Color(0xFF1A1410),
    secondary: Color(0xFF587A52), // verde-musgo
    onSecondary: Color(0xFFF0E8D0),
    error: Color(0xFFCC4444),
    onError: Color(0xFFF0E8D0),
    surface: Color(0xFF1A1410), // couro escuro
    onSurface: Color(0xFFF0E8D0), // papel creme
    surfaceContainerHighest: Color(0xFF2C2318), // cartão escuro
    onSurfaceVariant: Color(0xFFB89E78), // pergaminho
  );

  static ThemeData _buildElegantTheme(bool isDark) {
    final colorScheme = isDark ? _darkColorScheme : _lightColorScheme;

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      fontFamily: GoogleFonts.crimsonText().fontFamily,
      scaffoldBackgroundColor: colorScheme.surface,

      // Elegant Typography with Serif Fonts
      textTheme: GoogleFonts.crimsonTextTextTheme().copyWith(
        headlineLarge: GoogleFonts.crimsonText(
          fontSize: 32,
          fontWeight: FontWeight.w400,
          height: 1.2,
          color: colorScheme.onSurface,
        ),
        headlineMedium: GoogleFonts.crimsonText(
          fontSize: 28,
          fontWeight: FontWeight.w400,
          height: 1.25,
          color: colorScheme.onSurface,
        ),
        headlineSmall: GoogleFonts.crimsonText(
          fontSize: 24,
          fontWeight: FontWeight.w500,
          height: 1.3,
          color: colorScheme.onSurface,
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

      dividerColor: colorScheme.secondary.withValues(alpha: 0.25),

      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 1,
        centerTitle: true,
        titleTextStyle: GoogleFonts.crimsonText(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: colorScheme.onPrimary,
        ),
        iconTheme: IconThemeData(color: colorScheme.onPrimary),
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
        fillColor: colorScheme.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: colorScheme.secondary.withValues(alpha: 0.35),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        labelStyle: GoogleFonts.libreFranklin(color: colorScheme.onSurface),
        hintStyle: GoogleFonts.libreFranklin(
          color: colorScheme.onSurface.withValues(alpha: 0.7),
        ),
      ),

      // Card Design Inspired by Bookmarks
      cardTheme: CardThemeData(
        color: isDark ? const Color(0xFF2C2318) : const Color(0xFFEDE0C0),
        elevation: 2,
        shadowColor: colorScheme.primary.withValues(alpha: 0.18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.only(bottom: 12),
      ),

      // FAB with Bookmark-like Design
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
        backgroundColor: isDark
            ? const Color(0xFF587A52)
            : const Color(0xFF1A1410),
        contentTextStyle: GoogleFonts.libreFranklin(
          color: const Color(0xFFF2E5BD),
          fontSize: 14,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ThemeNotifier(),
      child: Consumer<ThemeNotifier>(
        builder: (context, themeNotifier, child) => MultiProvider(
          providers: [
            Provider<AuthService>(create: (_) => AuthService()),
            Provider<FirestoreService>(create: (_) => FirestoreService()),
            Provider<ApiService>(create: (_) => ApiService()),
            Provider<SettingsService>(create: (_) => SettingsService()),
          ],
          child: MaterialApp(
            title: 'Onde Parei?',
            debugShowCheckedModeBanner: false,
            theme: _buildElegantTheme(false),
            darkTheme: _buildElegantTheme(true),
            themeMode: themeNotifier.isDarkMode
                ? ThemeMode.dark
                : ThemeMode.light,
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
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      },
    );
  }
}
