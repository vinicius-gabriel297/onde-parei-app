import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'screens/home/home_shell.dart';
import 'services/auth_service.dart';
import 'services/firestore_service.dart';
import 'services/search_history_service.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final themeController = ThemeController();
  await themeController.load();

  runApp(MyApp(themeController: themeController));
}

class MyApp extends StatelessWidget {
  final ThemeController themeController;

  const MyApp({super.key, required this.themeController});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeController>.value(value: themeController),
        Provider<AuthService>(create: (_) => AuthService()),
        Provider<FirestoreService>(create: (_) => FirestoreService()),
        Provider<SearchHistoryService>(create: (_) => SearchHistoryService()),
      ],
      child: Consumer<ThemeController>(
        builder: (context, theme, _) => MaterialApp(
          title: 'Onde Parei?',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: theme.mode,
          home: const AuthWrapper(),
          routes: {
            '/login': (_) => const LoginScreen(),
            '/signup': (_) => const SignupScreen(),
            '/home': (_) => const HomeShell(),
          },
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

    // Quando o Android mata o app em segundo plano e a pessoa volta depois de
    // muito tempo, o processo sobe do zero e o stream ainda não emitiu nada.
    // Partir do `currentUser` — que o Firebase já restaurou do disco antes do
    // primeiro frame — evita mandar quem está logado para a tela de login.
    return StreamBuilder<User?>(
      stream: authService.authStateChanges,
      initialData: authService.currentUser,
      builder: (context, snapshot) {
        if (!snapshot.hasData &&
            snapshot.connectionState == ConnectionState.waiting) {
          return const _SplashScreen();
        }
        return snapshot.data == null ? const LoginScreen() : const HomeShell();
      },
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_stories_rounded, size: 56, color: scheme.primary),
            const SizedBox(height: 20),
            Text('Onde Parei?', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 24),
            SizedBox(
              width: 120,
              child: LinearProgressIndicator(
                minHeight: 3,
                backgroundColor: scheme.surfaceContainerHigh,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
