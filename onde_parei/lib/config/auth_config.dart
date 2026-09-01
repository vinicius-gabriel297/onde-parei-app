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
/// Para preencher: Firebase Console → Authentication → Sign-in method → Google,
/// e copie o "Web SDK configuration → Web client ID". Depois passe no build:
///   flutter build appbundle --dart-define=GOOGLE_SERVER_CLIENT_ID=...apps.googleusercontent.com
abstract final class AuthConfig {
  static const googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
  );

  static bool get hasGoogleServerClientId => googleServerClientId.isNotEmpty;
}
