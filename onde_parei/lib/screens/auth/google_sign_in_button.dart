import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/auth_config.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';

/// Botão "Continuar com Google", compartilhado pelo login e pelo cadastro.
///
/// Cuida do próprio estado de carregamento e devolve o erro pelo [onError],
/// para cada tela mostrar do jeito dela. Depois de entrar não navega: quem
/// escuta `authStateChanges` é o `AuthWrapper`, que troca a tela sozinho.
class GoogleSignInButton extends StatefulWidget {
  /// Desliga o botão enquanto a tela está ocupada com outra coisa (o login por
  /// e-mail, por exemplo).
  final bool enabled;
  final ValueChanged<String> onError;

  const GoogleSignInButton({
    super.key,
    required this.onError,
    this.enabled = true,
  });

  /// No Android o login depende de um client ID informado no build. Sem ele o
  /// botão não deve nem aparecer: melhor não oferecer do que oferecer quebrado.
  /// No navegador o `firebase_auth` resolve sozinho, então sempre aparece.
  static bool get isAvailable => kIsWeb || AuthConfig.hasGoogleServerClientId;

  @override
  State<GoogleSignInButton> createState() => _GoogleSignInButtonState();
}

class _GoogleSignInButtonState extends State<GoogleSignInButton> {
  bool _busy = false;

  Future<void> _signIn() async {
    setState(() => _busy = true);
    try {
      await context.read<AuthService>().signInWithGoogle();
      // Retorno nulo é desistência: a pessoa fechou o seletor. Nada a fazer.
    } catch (e) {
      if (mounted) widget.onError('$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!GoogleSignInButton.isAvailable) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final disabled = _busy || !widget.enabled;

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: Divider(color: scheme.outlineVariant)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text('ou', style: theme.textTheme.labelSmall),
            ),
            Expanded(child: Divider(color: scheme.outlineVariant)),
          ],
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 52,
          width: double.infinity,
          child: OutlinedButton(
            onPressed: disabled ? null : _signIn,
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: scheme.outlineVariant),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
            child: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const _GoogleMark(),
                      const SizedBox(width: 10),
                      Text(
                        'Continuar com Google',
                        style: theme.textTheme.titleSmall,
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}

/// Marca tipográfica provisória. O logo oficial do Google é um asset com regras
/// próprias de uso; enquanto ele não entra em `assets/`, isto segura o lugar.
class _GoogleMark extends StatelessWidget {
  const _GoogleMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      child: const Text(
        'G',
        style: TextStyle(
          color: Color(0xFF4285F4),
          fontWeight: FontWeight.w700,
          fontSize: 14,
          height: 1.1,
        ),
      ),
    );
  }
}
