import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;

import '../config/api_keys.dart';
import '../models/api_models.dart';

/// Escopo da busca — permite pular fontes que o usuário não quer ver e,
/// com isso, cortar latência.
enum SearchScope { all, books, comics }

/// Estado incremental da busca. A UI recebe um snapshot a cada fonte que
/// termina, em vez de esperar todas.
class SearchSnapshot {
  final List<SearchResult> results;
  final int pendingSources;
  final int totalSources;
  final List<String> failedSources;

  const SearchSnapshot({
    required this.results,
    required this.pendingSources,
    required this.totalSources,
    this.failedSources = const [],
  });

  bool get isDone => pendingSources == 0;
  bool get isEmpty => results.isEmpty;
}

class _CacheEntry {
  final dynamic value;
  final DateTime expiresAt;
  _CacheEntry(this.value, this.expiresAt);
  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

/// Cache LRU simples em memória. Evita refazer a mesma requisição quando o
/// usuário apaga uma letra e digita de novo, ou volta para a tela de busca.
class _MemoryCache {
  static const int _maxEntries = 150;
  static final Map<String, _CacheEntry> _store = {};

  static dynamic get(String key) {
    final entry = _store[key];
    if (entry == null) return null;
    if (entry.isExpired) {
      _store.remove(key);
      return null;
    }
    // Reinsere para manter a ordem de uso (LinkedHashMap = ordem de inserção).
    _store.remove(key);
    _store[key] = entry;
    return entry.value;
  }

  static void put(String key, dynamic value, Duration ttl) {
    if (_store.length >= _maxEntries) {
      _store.remove(_store.keys.first);
    }
    _store[key] = _CacheEntry(value, DateTime.now().add(ttl));
  }

  static void clear() => _store.clear();
}

/// Limitador de taxa por host. Antes existia um único relógio estático
/// compartilhado por todas as APIs, o que fazia buscas paralelas se
/// atrasarem mutuamente.
class _RateLimiter {
  static final Map<String, DateTime> _nextAllowed = {};

  static Future<void> acquire(String host, Duration minInterval) async {
    if (minInterval == Duration.zero) return;

    final now = DateTime.now();
    final next = _nextAllowed[host];

    if (next == null || !next.isAfter(now)) {
      _nextAllowed[host] = now.add(minInterval);
      return;
    }

    final wait = next.difference(now);
    _nextAllowed[host] = next.add(minInterval);
    await Future<void>.delayed(wait);
  }
}

/// Disjuntor por fonte: depois de falhas seguidas (API fora do ar, CORS
/// bloqueado no Web…) a fonte é ignorada por alguns minutos em vez de
/// segurar a busca inteira até o timeout.
class _Breaker {
  static final Map<String, _Breaker> _breakers = {};

  static const List<Duration> _cooldowns = [
    Duration(minutes: 3),
    Duration(minutes: 10),
    Duration(minutes: 30),
  ];

  int _failures = 0;
  int _trips = 0;
  DateTime? _openUntil;

  static _Breaker of(String name) =>
      _breakers.putIfAbsent(name, () => _Breaker());

  bool get isOpen =>
      _openUntil != null && DateTime.now().isBefore(_openUntil!);

  void recordSuccess() {
    _failures = 0;
    _trips = 0;
    _openUntil = null;
  }

  void recordFailure() {
    _failures++;
    if (_failures < 2) return;

    // Espera crescente: uma fonte que nunca funciona neste ambiente deixa de
    // ser consultada a cada busca.
    final index = _trips.clamp(0, _cooldowns.length - 1);
    _openUntil = DateTime.now().add(_cooldowns[index]);
    _failures = 0;
    _trips++;
  }

  static void resetAll() {
    for (final breaker in _breakers.values) {
      breaker._failures = 0;
      breaker._trips = 0;
      breaker._openUntil = null;
    }
  }
}

class ApiService {
  static const String jikanBaseUrl = 'https://api.jikan.moe/v4';
  static const String openLibraryBaseUrl = 'https://openlibrary.org';
  static const String manhwaManhuaBaseUrl = 'https://api.mangadex.org';
  static const String kitsuBaseUrl = 'https://kitsu.io/api/edge';
  static const String _googleBooksBaseUrl =
      'https://www.googleapis.com/books/v1';

  /// Cliente único: reaproveita conexão TCP/TLS entre requisições.
  /// Cada `http.get` avulso abria um handshake novo.
  static final http.Client _client = http.Client();

  static const Duration _defaultTimeout = Duration(seconds: 7);
  static const Duration _cacheTtl = Duration(minutes: 10);

  // ─── Camada HTTP ──────────────────────────────────────────────────────────

  static Future<dynamic> _getJson(
    Uri uri, {
    required String host,
    Duration timeout = _defaultTimeout,
    Duration cacheTtl = _cacheTtl,
    Duration minInterval = Duration.zero,
    Map<String, String> headers = const {'Accept': 'application/json'},
  }) async {
    final cacheKey = uri.toString();
    final cached = _MemoryCache.get(cacheKey);
    if (cached != null) return cached;

    await _RateLimiter.acquire(host, minInterval);

    final response = await _client.get(uri, headers: headers).timeout(timeout);

    if (response.statusCode == 200) {
      // utf8 explícito: sem isso acentos vinham corrompidos quando a resposta
      // não declara charset.
      final decoded = json.decode(utf8.decode(response.bodyBytes));
      _MemoryCache.put(cacheKey, decoded, cacheTtl);
      return decoded;
    }

    throw HttpException('$host respondeu ${response.statusCode}');
  }

  /// Executa uma fonte protegida por disjuntor.
  static Future<List<SearchResult>> _guarded(
    String name,
    Future<List<SearchResult>> Function() task,
  ) async {
    final breaker = _Breaker.of(name);
    if (breaker.isOpen) return const [];

    try {
      final result = await task();
      breaker.recordSuccess();
      return result;
    } catch (_) {
      breaker.recordFailure();
      rethrow;
    }
  }

  // ─── Mangás (Jikan / MyAnimeList) ─────────────────────────────────────────

  static Future<List<JikanManga>> searchMangas(
    String query, {
    int limit = 10,
  }) async {
    final uri = Uri.parse(
      '$jikanBaseUrl/manga'
      '?q=${Uri.encodeQueryComponent(query)}'
      '&limit=$limit'
      '&order_by=members&sort=desc&sfw=true',
    );

    final data = await _getJson(
      uri,
      host: 'jikan',
      // Jikan aceita ~3 req/s; o intervalo agora é só dele.
      minInterval: const Duration(milliseconds: 400),
      timeout: const Duration(seconds: 6),
    );

    return JikanResponse.fromJson(data as Map<String, dynamic>).data
        .where((m) => m.title.trim().isNotEmpty)
        .toList();
  }

  // ─── Manhwa / Manhua / Mangá (MangaDex) ───────────────────────────────────

  /// Uma única requisição. A versão anterior fazia 1 busca + 1 requisição de
  /// capa + 1 de detalhe + 1 por autor para CADA resultado (~25 chamadas
  /// sequenciais). Todos esses dados já vêm em `relationships`.
  static Future<List<MangaDexManga>> searchManhwaManhua(
    String query, {
    int limit = 10,
  }) async {
    final uri = Uri.parse(
      '$manhwaManhuaBaseUrl/manga'
      '?title=${Uri.encodeQueryComponent(query)}'
      '&limit=$limit'
      '&order[relevance]=desc'
      '&includes[]=cover_art&includes[]=author&includes[]=artist'
      '&contentRating[]=safe&contentRating[]=suggestive',
    );

    final data = await _getJson(
      uri,
      host: 'mangadex',
      timeout: const Duration(seconds: 7),
    );

    return MangaDexResponse.fromJson(data as Map<String, dynamic>).data
        .where((m) => m.getTitle().trim().isNotEmpty)
        .toList();
  }

  // ─── Kitsu (mangá / manhwa / manhua / light novel) ────────────────────────

  /// Única fonte de quadrinhos que responde CORS, portanto a que sustenta a
  /// busca no build Web. Uma requisição traz capa, nota, capítulos e tipo.
  static Future<List<KitsuManga>> searchKitsu(
    String query, {
    int limit = 10,
  }) async {
    final uri = Uri.parse(
      '$kitsuBaseUrl/manga'
      '?filter[text]=${Uri.encodeQueryComponent(query)}'
      '&page[limit]=$limit'
      '&fields[manga]=canonicalTitle,titles,abbreviatedTitles,description,'
      'synopsis,posterImage,subtype,chapterCount,averageRating,userCount,startDate',
    );

    // Kitsu é JSON:API — sem este Accept a resposta é 406.
    final data = await _getJson(
      uri,
      host: 'kitsu',
      timeout: const Duration(seconds: 5),
      headers: const {'Accept': 'application/vnd.api+json'},
    );
    final items = (data as Map<String, dynamic>)['data'] as List<dynamic>? ?? [];

    return items
        .map((item) => KitsuManga.fromJson(item as Map<String, dynamic>))
        .where((m) => m.title.trim().isNotEmpty)
        .toList();
  }

  // ─── Livros ───────────────────────────────────────────────────────────────

  static Future<List<GoogleBook>> searchBooksOnGoogle(
    String query, {
    int maxResults = 12,
  }) async {
    final keyParam = ApiKeys.googleBooks.isNotEmpty
        ? '&key=${ApiKeys.googleBooks}'
        : '';

    // `fields` corta o payload praticamente pela metade.
    const fields =
        'fields=items(id,volumeInfo(title,authors,description,imageLinks,'
        'publishedDate,pageCount,categories,averageRating,ratingsCount,'
        'language,industryIdentifiers))';

    final uri = Uri.parse(
      '$_googleBooksBaseUrl/volumes'
      '?q=${Uri.encodeQueryComponent(query)}'
      '&maxResults=$maxResults&printType=books&orderBy=relevance'
      '&$fields$keyParam',
    );

    final data = await _getJson(uri, host: 'googlebooks');

    return GoogleBooksResponse.fromJson(data as Map<String, dynamic>).items
        .where((book) => book.title.trim().isNotEmpty)
        .toList();
  }

  static Future<List<GoogleBook>> searchBooksOnOpenLibrary(
    String query, {
    int maxResults = 12,
  }) async {
    const fields =
        'fields=key,title,author_name,cover_i,first_publish_year,edition_count,'
        'ratings_average,ratings_count,want_to_read_count,already_read_count,'
        'number_of_pages_median,language,isbn';

    final uri = Uri.parse(
      '$openLibraryBaseUrl/search.json'
      '?q=${Uri.encodeQueryComponent(query)}'
      '&limit=$maxResults&$fields',
    );

    final data = await _getJson(uri, host: 'openlibrary');
    final docs = (data as Map<String, dynamic>)['docs'] as List<dynamic>? ?? [];

    return docs
        .map((doc) => GoogleBook.fromOpenLibrary(doc as Map<String, dynamic>))
        .where((book) => book.title.trim().isNotEmpty)
        .toList();
  }

  /// Mantido para compatibilidade: Google Books com fallback no Open Library.
  static Future<List<GoogleBook>> searchBooks(
    String query, {
    int maxResults = 12,
  }) async {
    try {
      final results = await searchBooksOnGoogle(query, maxResults: maxResults);
      if (results.isNotEmpty) return results;
    } catch (_) {
      // Cai para o Open Library.
    }
    return searchBooksOnOpenLibrary(query, maxResults: maxResults);
  }

  // ─── Busca unificada e progressiva ────────────────────────────────────────

  /// Dispara todas as fontes em paralelo e emite um snapshot a cada fonte que
  /// responde. A tela mostra os primeiros resultados em ~1s em vez de esperar
  /// a fonte mais lenta.
  ///
  /// [catalogLookup] é injetado pela tela (catálogo local no Firestore) para
  /// manter este serviço livre de dependências do Firebase.
  static Stream<SearchSnapshot> searchStream(
    String query, {
    SearchScope scope = SearchScope.all,
    Future<List<SearchResult>> Function(String query)? catalogLookup,
  }) {
    final normalizedQuery = query.trim();
    final controller = StreamController<SearchSnapshot>();

    if (normalizedQuery.isEmpty) {
      controller.add(
        const SearchSnapshot(results: [], pendingSources: 0, totalSources: 0),
      );
      controller.close();
      return controller.stream;
    }

    final wantsBooks = scope != SearchScope.comics;
    final wantsComics = scope != SearchScope.books;

    final sources = <String, Future<List<SearchResult>>>{};

    if (wantsBooks) {
      if (catalogLookup != null) {
        sources['Catálogo'] = catalogLookup(normalizedQuery);
      }
      sources['Google Books'] = _guarded(
        'googlebooks',
        () async => (await searchBooksOnGoogle(normalizedQuery, maxResults: 14))
            .map((b) => SearchResult.fromBook(b))
            .toList(),
      );
      sources['Open Library'] = _guarded(
        'openlibrary',
        () async =>
            (await searchBooksOnOpenLibrary(normalizedQuery, maxResults: 12))
                .map(
                  (b) =>
                      SearchResult.fromBook(b, source: SearchSource.openLibrary),
                )
                .toList(),
      );
    }

    if (wantsComics) {
      sources['MangaDex'] = _guarded(
        'mangadex',
        () async =>
            (await searchManhwaManhua(normalizedQuery, limit: 12))
                .map(SearchResult.fromMangaDex)
                .toList(),
      );
      sources['Kitsu'] = _guarded(
        'kitsu',
        () async => (await searchKitsu(normalizedQuery, limit: 12))
            .map(SearchResult.fromKitsu)
            .toList(),
      );
      sources['MyAnimeList'] = _guarded(
        'jikan',
        () async => (await searchMangas(normalizedQuery, limit: 12))
            .map(SearchResult.fromManga)
            .toList(),
      );
    }

    final merged = <String, SearchResult>{};
    final failed = <String>[];
    var pending = sources.length;
    var cancelled = false;

    void emit() {
      if (cancelled || controller.isClosed) return;
      controller.add(
        SearchSnapshot(
          results: rank(merged.values.toList(), normalizedQuery),
          pendingSources: pending,
          totalSources: sources.length,
          failedSources: List.unmodifiable(failed),
        ),
      );
    }

    emit();

    for (final entry in sources.entries) {
      entry.value
          .then((results) {
            if (cancelled) return;
            for (final result in results) {
              _mergeInto(merged, result);
            }
          })
          .catchError((_) {
            if (!cancelled) failed.add(entry.key);
          })
          .whenComplete(() {
            if (cancelled) return;
            pending--;
            emit();
            if (pending == 0 && !controller.isClosed) controller.close();
          });
    }

    controller.onCancel = () {
      cancelled = true;
    };

    return controller.stream;
  }

  /// Prioridade entre fontes ao deduplicar o mesmo título.
  static int _sourceRank(SearchSource source) {
    switch (source) {
      case SearchSource.catalog:
        return 0;
      case SearchSource.mangaDex:
        return 1;
      case SearchSource.kitsu:
        return 2;
      case SearchSource.jikan:
        return 3;
      case SearchSource.googleBooks:
        return 4;
      case SearchSource.openLibrary:
        return 5;
    }
  }

  static void _mergeInto(
    Map<String, SearchResult> merged,
    SearchResult candidate,
  ) {
    if (candidate.title.trim().isEmpty) return;

    final key = candidate.dedupeKey;
    final existing = merged[key];
    if (existing == null) {
      merged[key] = candidate;
      return;
    }

    // Prefere o que tem capa; depois, a fonte de maior prioridade.
    final existingHasCover = (existing.imageUrl ?? '').isNotEmpty;
    final candidateHasCover = (candidate.imageUrl ?? '').isNotEmpty;

    if (candidateHasCover && !existingHasCover) {
      merged[key] = candidate;
      return;
    }
    if (!candidateHasCover && existingHasCover) return;

    if (_sourceRank(candidate.source) < _sourceRank(existing.source)) {
      merged[key] = candidate;
    }
  }

  // ─── Ranking por relevância ───────────────────────────────────────────────

  static String _normalize(String value) {
    const withAccents = 'áàâãäéèêëíìîïóòôõöúùûüçñ';
    const withoutAccents = 'aaaaaeeeeiiiiooooouuuucn';

    var text = value.toLowerCase();
    for (var i = 0; i < withAccents.length; i++) {
      text = text.replaceAll(withAccents[i], withoutAccents[i]);
    }
    return text.replaceAll(RegExp(r'[^a-z0-9 ]'), ' ').replaceAll(
      RegExp(r'\s+'),
      ' ',
    ).trim();
  }

  static final RegExp _volumePattern = RegExp(
    r'\b(vol|volume|tomo|tome|deluxe|omnibus|box set)\b|\b\d{1,3}$',
  );

  /// Produtos derivados que poluem a busca (livro de colorir, guia, diário…).
  static final RegExp _derivativePattern = RegExp(
    r'\b(coloring|colouring|notebook|journal|diary|guide|guia|handbook|'
    r'cookbook|quiz|trivia|unofficial|nao oficial|art of|making of|'
    r'activity|sketchbook|calendar|calendario|planner|poster)\b',
  );

  /// Distância de edição limitada a 1 — casa "duna" com "dune" sem
  /// transformar a busca em algo permissivo demais.
  static bool _nearMatch(String a, String b) {
    if (a == b) return true;
    if (a.length < 4 || b.length < 4) return false;
    if ((a.length - b.length).abs() > 1) return false;

    var i = 0;
    var j = 0;
    var edits = 0;
    while (i < a.length && j < b.length) {
      if (a[i] == b[j]) {
        i++;
        j++;
        continue;
      }
      if (++edits > 1) return false;
      if (a.length > b.length) {
        i++;
      } else if (b.length > a.length) {
        j++;
      } else {
        i++;
        j++;
      }
    }
    return edits + (a.length - i) + (b.length - j) <= 1;
  }

  /// Pontua um título isolado contra a busca normalizada.
  static double _titleScore(String rawTitle, String query, List<String> tokens) {
    final title = _normalize(rawTitle);
    if (title.isEmpty) return -1000;

    var score = 0.0;
    if (title == query) {
      score += 1200;
    } else if (title.startsWith('$query ') || title.startsWith('$query:')) {
      score += 780;
    } else if (title.startsWith(query)) {
      score += 700;
    } else if (title.contains(' $query')) {
      score += 540;
    } else if (title.contains(query)) {
      score += 400;
    }

    if (tokens.isNotEmpty) {
      final titleTokens = title.split(' ').toList();
      final matched = tokens
          .where((token) => titleTokens.any((t) => _nearMatch(t, token)))
          .length;
      score += (matched / tokens.length) * 280;
    }

    // Título curto e direto tende a ser a obra principal, não um spin-off.
    score -= math.min(title.length / 14.0, 10);

    // "Solo Leveling, Vol. 5" não deve ganhar de "Solo Leveling".
    final queryHasDigits = RegExp(r'\d').hasMatch(query);
    if (!queryHasDigits && _volumePattern.hasMatch(title)) score -= 70;
    if (_derivativePattern.hasMatch(title)) score -= 260;

    return score;
  }

  /// Ordena por quanto o título casa com a busca; popularidade só desempata.
  /// Antes a ordenação era por tipo (livros sempre primeiro), o que enterrava
  /// o mangá certo embaixo de livros irrelevantes.
  static List<SearchResult> rank(List<SearchResult> results, String query) {
    final normalizedQuery = _normalize(query);
    final tokens = normalizedQuery
        .split(' ')
        .where((t) => t.length > 1)
        .toList();

    final relevant = <MapEntry<SearchResult, double>>[];
    final fallback = <MapEntry<SearchResult, double>>[];

    for (final result in results) {
      // Considera também os títulos alternativos: o nome oficial em inglês
      // costuma ficar fora do campo `title` no MangaDex.
      var best = _titleScore(result.title, normalizedQuery, tokens);
      for (final alternate in result.alternateTitles) {
        final alternateScore =
            _titleScore(alternate, normalizedQuery, tokens) * 0.85;
        if (alternateScore > best) best = alternateScore;
      }

      final authorText = _normalize((result.authors ?? const []).join(' '));
      final authorMatch =
          tokens.isNotEmpty &&
          authorText.isNotEmpty &&
          tokens.every((token) => authorText.contains(token));

      var score = best;
      if (authorMatch) score += 180;
      score += math.log(result.popularity + 1) * 9;
      if ((result.score ?? 0) > 0) score += result.score! * 6;
      if ((result.imageUrl ?? '').isEmpty) score -= 45;
      if (result.source == SearchSource.catalog) score += 30;
      if ((result.description ?? '').isNotEmpty) score += 12;

      final entry = MapEntry(result, score);
      if (best > 0 || authorMatch) {
        relevant.add(entry);
      } else {
        fallback.add(entry);
      }
    }

    // Só mostra os fracos se não sobrou nada realmente relevante.
    final chosen = relevant.isNotEmpty ? relevant : fallback;
    chosen.sort((a, b) {
      final byScore = b.value.compareTo(a.value);
      if (byScore != 0) return byScore;
      return a.key.title.toLowerCase().compareTo(b.key.title.toLowerCase());
    });

    return chosen.map((e) => e.key).toList();
  }

  /// Compatibilidade com o código antigo: aguarda todas as fontes.
  static Future<List<SearchResult>> searchAll(String query) async {
    final snapshot = await searchStream(query).last;
    if (snapshot.results.isEmpty) {
      throw Exception('Nenhum resultado encontrado. Tente outros termos.');
    }
    return snapshot.results;
  }

  // ─── Consultas pontuais ───────────────────────────────────────────────────

  static Future<JikanManga?> getMangaById(int malId) async {
    try {
      final data = await _getJson(
        Uri.parse('$jikanBaseUrl/manga/$malId'),
        host: 'jikan',
        minInterval: const Duration(milliseconds: 400),
      );
      return JikanManga.fromJson(
        (data as Map<String, dynamic>)['data'] as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<GoogleBook?> getBookById(String bookId) async {
    try {
      final data = await _getJson(
        Uri.parse('$openLibraryBaseUrl/works/$bookId.json'),
        host: 'openlibrary',
      );
      final map = data as Map<String, dynamic>;
      return GoogleBook.fromOpenLibrary({
        'key': '/works/$bookId',
        'title': map['title']?.toString() ?? '',
        'first_publish_year': map['first_publish_date']?.toString(),
      });
    } catch (_) {
      return null;
    }
  }

  /// Reabre disjuntores e limpa o cache — usado pelo "tentar novamente".
  static void reset() {
    _Breaker.resetAll();
    _MemoryCache.clear();
  }
}

class HttpException implements Exception {
  final String message;
  HttpException(this.message);
  @override
  String toString() => message;
}
