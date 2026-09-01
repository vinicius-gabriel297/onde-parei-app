import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ui_kit.dart';
import 'auth_scaffold.dart';
import 'google_sign_in_button.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await context.read<AuthService>().signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
    } catch (e) {
      if (mounted) setState(() => _errorMessage = '$e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _errorMessage = 'Informe seu e-mail para recuperar a senha.');
      return;
    }

    try {
      await context.read<AuthService>().resetPassword(email);
      if (mounted) {
        AppSnack.show(context, 'Enviamos um e-mail de recuperação para $email.');
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AuthScaffold(
      title: 'Bem-vindo de volta',
      subtitle: 'Sua estante está esperando por você.',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(
                labelText: 'E-mail',
                prefixIcon: Icon(Icons.mail_outline_rounded, size: 19),
              ),
              validator: (value) {
                final text = (value ?? '').trim();
                if (text.isEmpty) return 'Informe seu e-mail';
                if (!text.contains('@')) return 'E-mail inválido';
                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              autofillHints: const [AutofillHints.password],
              onFieldSubmitted: (_) => _login(),
              decoration: InputDecoration(
                labelText: 'Senha',
                prefixIcon: const Icon(Icons.lock_outline_rounded, size: 19),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 19,
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              validator: (value) => (value ?? '').isEmpty
                  ? 'Informe sua senha'
                  : null,
            ),

            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _isLoading ? null : _resetPassword,
                child: const Text('Esqueci minha senha'),
              ),
            ),

            if (_errorMessage != null) ...[
              const SizedBox(height: 4),
              AuthErrorBox(message: _errorMessage!),
              const SizedBox(height: 8),
            ],

            const SizedBox(height: 6),
            SizedBox(
              height: 52,
              child: FilledButton(
                onPressed: _isLoading ? null : _login,
                child: _isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Entrar'),
              ),
            ),

            const SizedBox(height: 20),
            GoogleSignInButton(
              enabled: !_isLoading,
              onError: (message) => setState(() => _errorMessage = message),
            ),

            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Ainda não tem conta?', style: theme.textTheme.bodySmall),
                TextButton(
                  onPressed: _isLoading
                      ? null
                      : () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SignupScreen(),
                          ),
                        ),
                  child: const Text('Criar conta'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class AuthErrorBox extends StatelessWidget {
  final String message;

  const AuthErrorBox({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: scheme.error.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, size: 18, color: scheme.error),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message.replaceFirst('Exception: ', ''),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.error,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
