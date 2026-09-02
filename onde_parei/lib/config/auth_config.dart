/// Identificadores públicos do login com Google.
///
/// O `serverClientId` é o OAuth client ID **do tipo Web** do projeto Firebase —
/// mesmo no Android, é ele que o Google exige para devolver o `idToken` que o
/// Firebase consome. Não é segredo (vai no binário de qualquer jeito), por isso
/// mora num arquivo versionado, e não em `api_keys.dart`.
///
/// Enquanto estiver vazio, o botão do Google não aparece no Android — melhor
/// esconder do que oferecer um caminho que falha. No Web nada disso é
/// necessário: o `firebase_auth` resolve pelo popup.
///
/// O valor abaixo é o do projeto `onde-parei-ea32c` (Firebase Console →
/// Authentication → Sign-in method → Google → "Web SDK configuration"). Fica
/// fixo para nenhum build sair sem ele por esquecimento; o `--dart-define` de
/// mesmo nome ainda sobrepõe, se um dia houver outro projeto.
abstract final class AuthConfig {
  static const googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    defaultValue:
        '538339439123-rjm39rn8v6os7bnmadtpfpn1u89tgoqp.apps.googleusercontent.com',
  );

  static bool get hasGoogleServerClientId => googleServerClientId.isNotEmpty;
}
