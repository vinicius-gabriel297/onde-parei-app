import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';

import '../config/auth_config.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Stream para acompanhar mudanças no estado de autenticação
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Usuário atual
  User? get currentUser => _auth.currentUser;

  // Verificar se usuário está logado
  bool get isAuthenticated => currentUser != null;

  /// Conta que entrou pelo Google não tem senha própria — nada de pedir uma
  /// para confirmar operações sensíveis.
  bool get isGoogleUser =>
      currentUser?.providerData.any((p) => p.providerId == 'google.com') ??
      false;

  // Login com email e senha
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Cadastro com email e senha
  Future<UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      return await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  /// Entra com a conta Google.
  ///
  /// Dois caminhos, porque as plataformas resolvem isso de formas diferentes:
  /// no navegador o próprio `firebase_auth` abre um popup e não precisa de mais
  /// nada; no Android é o `google_sign_in` quem fala com o Credential Manager e
  /// devolve um `idToken`, que só então vira credencial do Firebase.
  ///
  /// Devolve `null` quando a pessoa fecha o seletor sem escolher conta — isso é
  /// desistência, não erro, e a tela não deve mostrar alerta nenhum.
  Future<UserCredential?> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        final provider = GoogleAuthProvider()
          // Sem isto o Google reusa a última conta em silêncio, e quem tem mais
          // de uma nunca consegue trocar.
          ..setCustomParameters({'prompt': 'select_account'});
        return await _auth.signInWithPopup(provider);
      }

      if (!AuthConfig.hasGoogleServerClientId) {
        throw Exception(
          'Login com Google não configurado neste build. Informe o '
          'GOOGLE_SERVER_CLIENT_ID ao compilar.',
        );
      }

      final googleSignIn = GoogleSignIn.instance;
      await googleSignIn.initialize(
        serverClientId: AuthConfig.googleServerClientId,
      );

      final account = await googleSignIn.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) {
        throw Exception('O Google não devolveu as credenciais da conta.');
      }

      return await _auth.signInWithCredential(
        GoogleAuthProvider.credential(idToken: idToken),
      );
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      throw Exception(_handleGoogleException(e));
    } on FirebaseAuthException catch (e) {
      // O popup fechado pelo usuário chega como exceção; também é desistência.
      if (e.code == 'popup-closed-by-user' || e.code == 'cancelled-popup-request') {
        return null;
      }
      throw _handleAuthException(e);
    }
  }

  // Logout
  Future<void> signOut() async {
    try {
      // Sem isto, o Android reentra sozinho na mesma conta no próximo login e
      // "sair" não parece ter funcionado.
      if (!kIsWeb) {
        try {
          await GoogleSignIn.instance.signOut();
        } catch (_) {
          // Nunca tinha entrado pelo Google; não há o que desfazer.
        }
      }
      await _auth.signOut();
    } catch (e) {
      throw Exception('Erro ao fazer logout: $e');
    }
  }

  // Recuperar senha
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Atualizar senha
  Future<void> updatePassword(String newPassword) async {
    try {
      await currentUser?.updatePassword(newPassword);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Atualizar email
  Future<void> updateEmail(String newEmail) async {
    try {
      await currentUser?.verifyBeforeUpdateEmail(newEmail);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Reautenticar usuário (necessário para operações sensíveis)
  Future<void> reauthenticate(String email, String password) async {
    try {
      final credential = EmailAuthProvider.credential(
        email: email,
        password: password,
      );
      await currentUser?.reauthenticateWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  /// Reautenticação de quem entrou pelo Google: em vez de senha, refaz o
  /// mesmo caminho do login. Necessária antes de excluir a conta, que o
  /// Firebase só aceita com credencial recente.
  Future<void> reauthenticateWithGoogle() async {
    final user = currentUser;
    if (user == null) return;

    try {
      if (kIsWeb) {
        await user.reauthenticateWithPopup(GoogleAuthProvider());
        return;
      }

      if (!AuthConfig.hasGoogleServerClientId) {
        throw Exception(
          'Login com Google não configurado neste build. Informe o '
          'GOOGLE_SERVER_CLIENT_ID ao compilar.',
        );
      }

      final googleSignIn = GoogleSignIn.instance;
      await googleSignIn.initialize(
        serverClientId: AuthConfig.googleServerClientId,
      );

      final account = await googleSignIn.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) {
        throw Exception('O Google não devolveu as credenciais da conta.');
      }

      await user.reauthenticateWithCredential(
        GoogleAuthProvider.credential(idToken: idToken),
      );
    } on GoogleSignInException catch (e) {
      throw Exception(_handleGoogleException(e));
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Atualizar nome de exibicao (fica salvo no Firebase e sincroniza entre
  // dispositivos, diferente do SharedPreferences local)
  Future<void> updateDisplayName(String displayName) async {
    try {
      await currentUser?.updateDisplayName(displayName.trim());
      await currentUser?.reload();
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Excluir conta
  Future<void> deleteAccount() async {
    try {
      await currentUser?.delete();
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  String _handleGoogleException(GoogleSignInException e) {
    switch (e.code) {
      case GoogleSignInExceptionCode.canceled:
        return 'Login cancelado.';
      case GoogleSignInExceptionCode.interrupted:
        return 'O login foi interrompido. Tente de novo.';
      case GoogleSignInExceptionCode.clientConfigurationError:
        return 'Login com Google mal configurado neste app.';
      case GoogleSignInExceptionCode.providerConfigurationError:
        return 'O Google recusou a configuração deste app.';
      case GoogleSignInExceptionCode.uiUnavailable:
        return 'Não deu para abrir a tela do Google neste aparelho.';
      case GoogleSignInExceptionCode.userMismatch:
        return 'A conta escolhida não confere com a esperada.';
      case GoogleSignInExceptionCode.unknownError:
        return 'Não deu para entrar com o Google. Tente de novo.';
    }
  }

  // Tratamento de erros de autenticação
  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'Usuário não encontrado.';
      case 'wrong-password':
        return 'Senha incorreta.';
      case 'email-already-in-use':
        return 'Este email já está em uso.';
      case 'weak-password':
        return 'A senha deve ter pelo menos 6 caracteres.';
      case 'invalid-email':
        return 'Email inválido.';
      case 'user-disabled':
        return 'Esta conta foi desabilitada.';
      case 'too-many-requests':
        return 'Muitas tentativas. Tente novamente mais tarde.';
      case 'operation-not-allowed':
        return 'Operação não permitida.';
      case 'account-exists-with-different-credential':
        return 'Já existe uma conta com este e-mail. Entre com e-mail e senha.';
      case 'network-request-failed':
        return 'Erro de conexão. Verifique sua internet.';
      case 'requires-recent-login':
        return 'Esta operação requer autenticação recente. Faça login novamente.';
      default:
        return 'Erro inesperado: ${e.message}';
    }
  }
}
