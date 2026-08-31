import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Controla e persiste a preferência de tema. Antes o app tinha duas classes
/// `ThemeNotifier` diferentes (main.dart e settings_screen.dart), então o
/// botão de tema das configurações nunca chegava no provider real.
class ThemeController extends ChangeNotifier {
  static const _prefsKey = 'themeMode';

  ThemeMode _mode = ThemeMode.dark;
  bool _loaded = false;

  ThemeMode get mode => _mode;
  bool get isLoaded => _loaded;
  bool get isDarkMode => _mode == ThemeMode.dark;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(_prefsKey);
      _mode = switch (stored) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        'system' => ThemeMode.system,
        _ => ThemeMode.dark,
      };
    } catch (_) {
      _mode = ThemeMode.dark;
    } finally {
      _loaded = true;
      notifyListeners();
    }
  }

  Future<void> setMode(ThemeMode mode) async {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, mode.name);
    } catch (_) {
      // Preferência não persistida não deve quebrar a troca de tema.
    }
  }

  Future<void> setDarkMode(bool value) =>
      setMode(value ? ThemeMode.dark : ThemeMode.light);

  Future<void> toggle() => setDarkMode(!isDarkMode);
}
