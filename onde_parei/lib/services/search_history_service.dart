import 'package:shared_preferences/shared_preferences.dart';

/// Guarda as últimas buscas para preencher a tela vazia da busca.
class SearchHistoryService {
  static const _key = 'recentSearches';
  static const _maxEntries = 8;

  List<String> _cache = const [];

  List<String> get cached => _cache;

  Future<List<String>> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _cache = prefs.getStringList(_key) ?? const [];
    } catch (_) {
      _cache = const [];
    }
    return _cache;
  }

  Future<List<String>> add(String term) async {
    final value = term.trim();
    if (value.length < 2) return _cache;

    final updated = <String>[value];
    for (final existing in _cache) {
      if (existing.toLowerCase() != value.toLowerCase()) updated.add(existing);
      if (updated.length >= _maxEntries) break;
    }
    _cache = updated;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_key, updated);
    } catch (_) {
      // Histórico é conveniência: falhar aqui não afeta a busca.
    }
    return _cache;
  }

  Future<void> clear() async {
    _cache = const [];
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (_) {
      // Ignorado de propósito.
    }
  }
}
