import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';
import 'auth_scaffold.dart';
import 'google_sign_in_button.dart';
import 'login_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _isLoading = false;
  bool _obscure = true;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _signup() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final auth = context.read<AuthService>();
    final navigator = Navigator.of(context);

    try {
      await auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      final name = _nameController.text.trim();
      if (name.isNotEmpty) {
        await auth.updateDisplayName(name);
      }

      if (mounted && navigator.canPop()) navigator.pop();
    } catch (e) {
      if (mounted) setState(() => _errorMessage = '$e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AuthScaffold(
      title: 'Criar conta',
      subtitle: 'Comece a registrar onde parou em cada leitura.',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nome (opcional)',
                prefixIcon: Icon(Icons.person_outline_rounded, size: 19),
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
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
              obscureText: _obscure,
              decoration: InputDecoration(
                labelText: 'Senha',
                prefixIcon: const Icon(Icons.lock_outline_rounded, size: 19),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 19,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              validator: (value) {
                if ((value ?? '').length < 6) {
                  return 'A senha precisa de pelo menos 6 caracteres';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _confirmController,
              obscureText: _obscure,
              onFieldSubmitted: (_) => _signup(),
              decoration: const InputDecoration(
                labelText: 'Confirmar senha',
                prefixIcon: Icon(Icons.lock_reset_rounded, size: 19),
              ),
              validator: (value) => value != _passwordController.text
                  ? 'As senhas não conferem'
                  : null,
            ),

            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              AuthErrorBox(message: _errorMessage!),
            ],

            const SizedBox(height: 22),
            SizedBox(
              height: 52,
              child: FilledButton(
                onPressed: _isLoading ? null : _signup,
                child: _isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Criar conta'),
              ),
            ),

            const SizedBox(height: 20),
            GoogleSignInButton(
              enabled: !_isLoading,
              onError: (message) => setState(() => _errorMessage = message),
            ),

            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Já tem conta?', style: theme.textTheme.bodySmall),
                TextButton(
                  onPressed: _isLoading
                      ? null
                      : () => Navigator.pop(context),
                  child: const Text('Entrar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
