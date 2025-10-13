import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_settings.dart';

class SettingsService {
  static const String _displayNameKey = 'displayName';
  static const String _isDarkModeKey = 'isDarkMode';
  static const String _languageKey = 'language';

  // Cache simples para configurações
  static final Map<String, UserSettings> _settingsCache = {};

  // Salvar configurações
  Future<void> saveSettings(UserSettings settings) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setString(_displayNameKey, settings.displayName);
      await prefs.setBool(_isDarkModeKey, settings.isDarkMode);
      await prefs.setString(_languageKey, settings.language);

      // Cache das configurações
      _settingsCache[settings.userId] = settings;

      print('✅ Configurações salvas: ${settings.displayName}, Dark Mode: ${settings.isDarkMode}');
    } catch (e) {
      print('❌ Erro ao salvar configurações: $e');
      throw Exception('Erro ao salvar configurações: $e');
    }
  }

  // Carregar configurações
  Future<UserSettings> loadSettings(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final displayName = prefs.getString(_displayNameKey) ?? '';
      final isDarkMode = prefs.getBool(_isDarkModeKey) ?? false;
      final language = prefs.getString(_languageKey) ?? 'pt_BR';

      final settings = UserSettings(
        userId: userId,
        displayName: displayName,
        isDarkMode: isDarkMode,
        language: language,
      );

      // Cache das configurações carregadas
      _currentSettings = settings;

      print('✅ Configurações carregadas: ${settings.displayName}, Dark Mode: ${settings.isDarkMode}');
      return settings;
    } catch (e) {
      print('❌ Erro ao carregar configurações: $e');
      // Retorna configurações padrão em caso de erro
      final defaultSettings = UserSettings(
        userId: userId,
        displayName: '',
        isDarkMode: false,
        language: 'pt_BR',
      );
      _currentSettings = defaultSettings;
      return defaultSettings;
    }
  }

  // Atualizar apenas o nome de exibição
  Future<void> updateDisplayName(String displayName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_displayNameKey, displayName);
      print('✅ Nome de exibição atualizado: $displayName');
    } catch (e) {
      print('❌ Erro ao atualizar nome: $e');
      throw Exception('Erro ao atualizar nome: $e');
    }
  }

  // Alternar tema
  Future<void> toggleDarkMode(bool isDarkMode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_isDarkModeKey, isDarkMode);
      print('✅ Tema alterado: ${isDarkMode ? 'Escuro' : 'Claro'}');
    } catch (e) {
      print('❌ Erro ao alterar tema: $e');
      throw Exception('Erro ao alterar tema: $e');
    }
  }

  // Verificar se é a primeira vez que o usuário usa o app
  Future<bool> isFirstTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isFirstTime = prefs.getBool('isFirstTime') ?? true;

      if (isFirstTime) {
        await prefs.setBool('isFirstTime', false);
      }

      return isFirstTime;
    } catch (e) {
      return true; // Em caso de erro, assume que é a primeira vez
    }
  }

  // Últimas configurações carregadas para acesso síncrono
  UserSettings? _currentSettings;

  // Getter para configurações atuais (usar com cuidado, prefira loadSettings)
  UserSettings? get currentSettings => _currentSettings;

  // Limpar todas as configurações (logout)
  Future<void> clearSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      _currentSettings = null;
      print('✅ Configurações limpas');
    } catch (e) {
      print('❌ Erro ao limpar configurações: $e');
    }
  }
}
