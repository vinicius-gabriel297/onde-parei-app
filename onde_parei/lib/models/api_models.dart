// ─────────────────────────────────────────────────────────────────────────────
// Modelos das APIs externas (Jikan / MangaDex / Google Books / Open Library)
// ─────────────────────────────────────────────────────────────────────────────

int? _toInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is String) return int.tryParse(value.trim());
  return null;
}

double? _toDouble(dynamic value) {
  if (value == null) return null;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) return double.tryParse(value.trim());
  return null;
}

/// Remove o nome nativo entre parênteses ("DAUL (다울)" -> "DAUL").
String _cleanAuthorName(String raw) {
  final match = RegExp(r'^(.*?)\s*\((.+)\)$').firstMatch(raw.trim());
  if (match == null) return raw.trim();
  final latin = match.group(1)!.trim();
  final inside = match.group(2)!;
  final insideIsLatin = RegExp(r'^[\x20-\x7E]+$').hasMatch(inside);
  if (latin.isEmpty || insideIsLatin) return raw.trim();
  return latin;
}

// ─── Jikan (MyAnimeList) ─────────────────────────────────────────────────────

class JikanManga {
  final int malId;
  final String title;
  final String? imageUrl;
  final String? synopsis;
  final List<String>? authors;
  final String? status;
  final int? volumes;
  final int? chapters;
  final double? score;
  final int? members;
  final String? publishedFrom;
  final List<String>? genres;

  /// "Manga", "Manhwa", "Manhua", "Light Novel"…
  final String? mediaType;

  JikanManga({
    required this.malId,
    required this.title,
    this.imageUrl,
    this.synopsis,
    this.authors,
    this.status,
    this.volumes,
    this.chapters,
    this.score,
    this.members,
    this.publishedFrom,
    this.genres,
    this.mediaType,
  });

  factory JikanManga.fromJson(Map<String, dynamic> json) {
    final images = json['images'] as Map<String, dynamic>?;
    final jpg = images?['jpg'] as Map<String, dynamic>?;
    final webp = images?['webp'] as Map<String, dynamic>?;

    final genres = <String>[];
    for (final key in ['genres', 'themes', 'demographics']) {
      final list = json[key] as List<dynamic>?;
      if (list == null) continue;
      for (final g in list) {
        final name = (g as Map<String, dynamic>)['name']?.toString();
        if (name != null && name.isNotEmpty && !genres.contains(name)) {
          genres.add(name);
        }
      }
    }

    return JikanManga(
      malId: _toInt(json['mal_id']) ?? 0,
      title:
          json['title']?.toString() ?? json['title_english']?.toString() ?? '',
      imageUrl:
          webp?['large_image_url']?.toString() ??
          jpg?['large_image_url']?.toString() ??
          jpg?['image_url']?.toString(),
      synopsis: json['synopsis']?.toString(),
      authors: (json['authors'] as List<dynamic>?)
          ?.map((a) => _cleanAuthorName((a['name'] ?? '').toString()))
          .where((a) => a.isNotEmpty)
          .toList(),
      status: json['status']?.toString(),
      volumes: _toInt(json['volumes']),
      chapters: _toInt(json['chapters']),
      score: _toDouble(json['score']),
      members: _toInt(json['members']),
      publishedFrom: (json['published'] as Map<String, dynamic>?)?['from']
          ?.toString()
          .split('-')
          .first,
      genres: genres.isEmpty ? null : genres,
      mediaType: json['type']?.toString(),
    );
  }
}

class JikanResponse {
  final List<JikanManga> data;

  JikanResponse({required this.data});

  factory JikanResponse.fromJson(Map<String, dynamic> json) {
    return JikanResponse(
      data:
          (json['data'] as List<dynamic>?)
              ?.map((item) => JikanManga.fromJson(item as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }
}

// ─── Google Books / Open Library ─────────────────────────────────────────────

class GoogleBook {
  final String id;
  final String title;
  final String? imageUrl;
  final String? description;
  final List<String>? authors;
  final String? publishedDate;
  final int? pageCount;
  final String? language;
  final String? isbn;
  final double? averageRating;
  final int? ratingsCount;
  final int? wantToReadCount;
  final int? alreadyReadCount;
  final int? editionCount;
  final List<String>? categories;

  GoogleBook({
    required this.id,
    required this.title,
    this.imageUrl,
    this.description,
    this.authors,
    this.publishedDate,
    this.pageCount,
    this.language,
    this.isbn,
    this.averageRating,
    this.ratingsCount,
    this.wantToReadCount,
    this.alreadyReadCount,
    this.editionCount,
    this.categories,
  });

  /// Popularidade normalizada, usada para desempate no ranking.
  int get popularity =>
      (ratingsCount ?? 0) * 3 +
      (wantToReadCount ?? 0) +
      (alreadyReadCount ?? 0) +
      (editionCount ?? 0) * 2;

  factory GoogleBook.fromOpenLibrary(Map<String, dynamic> json) {
    final key = (json['key'] as String?) ?? '';
    final coverId = _toInt(json['cover_i']);
    final authorNames = (json['author_name'] as List<dynamic>?)
        ?.map((e) => e.toString())
        .where((e) => e.trim().isNotEmpty)
        .toList();
    final languages = json['language'] as List<dynamic>?;
    final isbns = json['isbn'] as List<dynamic>?;

    return GoogleBook(
      id: key.replaceFirst('/works/', ''),
      title: json['title']?.toString() ?? '',
      imageUrl: coverId != null
          ? 'https://covers.openlibrary.org/b/id/$coverId-M.jpg'
          : null,
      description: null,
      authors: authorNames,
      publishedDate: json['first_publish_year']?.toString(),
      pageCount: _toInt(json['number_of_pages_median']),
      language: (languages != null && languages.isNotEmpty)
          ? languages.first.toString()
          : null,
      isbn: (isbns != null && isbns.isNotEmpty) ? isbns.first.toString() : null,
      averageRating: _toDouble(json['ratings_average']),
      ratingsCount: _toInt(json['ratings_count']),
      wantToReadCount: _toInt(json['want_to_read_count']),
      alreadyReadCount: _toInt(json['already_read_count']),
      editionCount: _toInt(json['edition_count']),
    );
  }

  factory GoogleBook.fromGoogle(Map<String, dynamic> json) {
    final volumeInfo = json['volumeInfo'] as Map<String, dynamic>?;
    final imageLinks = volumeInfo?['imageLinks'] as Map<String, dynamic>?;

    return GoogleBook(
      id: json['id']?.toString() ?? '',
      title: volumeInfo?['title']?.toString() ?? '',
      imageUrl: _bestGoogleImage(imageLinks),
      description: volumeInfo?['description']?.toString(),
      authors: (volumeInfo?['authors'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList(),
      publishedDate: volumeInfo?['publishedDate']?.toString(),
      pageCount: _toInt(volumeInfo?['pageCount']),
      language: volumeInfo?['language']?.toString(),
      isbn: _extractIsbn(volumeInfo),
      averageRating: _toDouble(volumeInfo?['averageRating']),
      ratingsCount: _toInt(volumeInfo?['ratingsCount']),
      categories: (volumeInfo?['categories'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList(),
    );
  }

  /// Compatibilidade: detecta o formato pelo payload.
  factory GoogleBook.fromJson(Map<String, dynamic> json) {
    if (json.containsKey('key') && json.containsKey('title')) {
      return GoogleBook.fromOpenLibrary(json);
    }
    return GoogleBook.fromGoogle(json);
  }

  static String? _bestGoogleImage(Map<String, dynamic>? imageLinks) {
    if (imageLinks == null) return null;

    final rawUrl =
        imageLinks['extraLarge'] ??
        imageLinks['large'] ??
        imageLinks['medium'] ??
        imageLinks['small'] ??
        imageLinks['thumbnail'] ??
        imageLinks['smallThumbnail'];

    if (rawUrl is! String || rawUrl.trim().isEmpty) return null;

    return rawUrl
        .replaceFirst('http://', 'https://')
        .replaceAll('&edge=curl', '')
        .replaceAll('?edge=curl', '')
        .replaceAll('zoom=1', 'zoom=2');
  }

  static String? _extractIsbn(Map<String, dynamic>? volumeInfo) {
    final identifiers = volumeInfo?['industryIdentifiers'] as List<dynamic>?;
    if (identifiers == null) return null;
    for (final identifier in identifiers) {
      final type = identifier['type']?.toString();
      if (type == 'ISBN_13' || type == 'ISBN_10') {
        return identifier['identifier']?.toString();
      }
    }
    return null;
  }
}

class GoogleBooksResponse {
  final List<GoogleBook> items;
  final int totalItems;

  GoogleBooksResponse({required this.items, required this.totalItems});

  factory GoogleBooksResponse.fromJson(Map<String, dynamic> json) {
    return GoogleBooksResponse(
      items:
          (json['items'] as List<dynamic>?)
              ?.map(
                (item) => GoogleBook.fromGoogle(item as Map<String, dynamic>),
              )
              .toList() ??
          const [],
      totalItems: _toInt(json['totalItems']) ?? 0,
    );
  }
}

// ─── MangaDex ────────────────────────────────────────────────────────────────

class MangaDexManga {
  final String id;
  final Map<String, String> title;
  final Map<String, String>? description;
  final String? coverUrl;
  final List<String>? authors;
  final String? contentRating;
  final String? status;
  final String? publicationDemographic;
  final List<String>? tags;
  final int? year;
  final String? originalLanguage;
  final int? lastChapter;

  /// Títulos alternativos (o título oficial em inglês costuma morar aqui
  /// quando `title` só traz a romanização do idioma original).
  final Map<String, String> altTitles;

  MangaDexManga({
    required this.id,
    required this.title,
    this.description,
    this.coverUrl,
    this.authors,
    this.contentRating,
    this.status,
    this.publicationDemographic,
    this.tags,
    this.year,
    this.originalLanguage,
    this.lastChapter,
    this.altTitles = const {},
  });

  /// Parsing completo a partir de UMA única resposta de busca que já veio com
  /// `includes[]=cover_art&includes[]=author&includes[]=artist`.
  /// Nenhuma requisição adicional é necessária.
  factory MangaDexManga.fromJson(Map<String, dynamic> json) {
    final id = json['id']?.toString() ?? '';
    final attrs = json['attributes'] as Map<String, dynamic>? ?? const {};
    final relationships = json['relationships'] as List<dynamic>? ?? const [];

    String? coverFileName;
    final authors = <String>[];

    for (final rel in relationships) {
      if (rel is! Map<String, dynamic>) continue;
      final type = rel['type']?.toString();
      final relAttrs = rel['attributes'] as Map<String, dynamic>?;
      if (relAttrs == null) continue;

      if (type == 'cover_art') {
        coverFileName ??= relAttrs['fileName']?.toString();
      } else if (type == 'author' || type == 'artist') {
        final name = relAttrs['name']?.toString();
        if (name != null && name.trim().isNotEmpty) {
          final clean = _cleanAuthorName(name);
          if (!authors.contains(clean)) authors.add(clean);
        }
      }
    }

    final altTitles = <String, String>{};
    for (final alt in (attrs['altTitles'] as List<dynamic>? ?? const [])) {
      if (alt is! Map<String, dynamic>) continue;
      for (final entry in alt.entries) {
        altTitles.putIfAbsent(entry.key, () => entry.value.toString());
      }
    }

    final tags = <String>[];
    for (final tag in (attrs['tags'] as List<dynamic>? ?? const [])) {
      final name = (tag['attributes']?['name']?['en'])?.toString();
      if (name != null && name.isNotEmpty) tags.add(name);
    }

    return MangaDexManga(
      id: id,
      title:
          (attrs['title'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, v.toString()),
          ) ??
          const {},
      description: (attrs['description'] as Map<String, dynamic>?)?.map(
        (k, v) => MapEntry(k, v.toString()),
      ),
      coverUrl: coverFileName != null
          ? 'https://uploads.mangadex.org/covers/$id/$coverFileName.512.jpg'
          : null,
      authors: authors.isEmpty ? null : authors,
      contentRating: attrs['contentRating']?.toString(),
      status: attrs['status']?.toString(),
      publicationDemographic: attrs['publicationDemographic']?.toString(),
      tags: tags.isEmpty ? null : tags,
      year: _toInt(attrs['year']),
      originalLanguage: attrs['originalLanguage']?.toString(),
      lastChapter: _toInt(attrs['lastChapter']),
      altTitles: altTitles,
    );
  }

  /// Prefere o título oficial em inglês, que muitas vezes só existe em
  /// `altTitles` — sem isso, "Solo Leveling" aparecia como
  /// "Na Honjaman Level-Up" e nunca casava com a busca.
  String getTitle() {
    return title['en'] ??
        altTitles['en'] ??
        title['ja-ro'] ??
        title['ko-ro'] ??
        title['zh-ro'] ??
        title['pt-br'] ??
        altTitles['ja-ro'] ??
        altTitles['ko-ro'] ??
        (title.isNotEmpty ? title.values.first : '');
  }

  /// Todos os títulos conhecidos, usados no ranking de relevância.
  List<String> get allTitles => <String>{
    ...title.values,
    ...altTitles.values,
  }.where((t) => t.trim().isNotEmpty).toList();

  String? getDescription() {
    if (description == null || description!.isEmpty) return null;
    final text =
        description!['pt-br'] ??
        description!['pt'] ??
        description!['en'] ??
        description!.values.first;
    return text.trim().isEmpty ? null : text.trim();
  }

  /// Classifica pela língua original: coreano = manhwa, chinês = manhua.
  String get inferredType {
    switch (originalLanguage) {
      case 'ko':
        return 'manhwa';
      case 'zh':
      case 'zh-hk':
        return 'manhua';
      default:
        return 'manga';
    }
  }
}

class MangaDexResponse {
  final List<MangaDexManga> data;
  final int total;

  MangaDexResponse({required this.data, required this.total});

  factory MangaDexResponse.fromJson(Map<String, dynamic> json) {
    return MangaDexResponse(
      data:
          (json['data'] as List<dynamic>?)
              ?.map(
                (item) => MangaDexManga.fromJson(item as Map<String, dynamic>),
              )
              .toList() ??
          const [],
      total: _toInt(json['total']) ?? 0,
    );
  }
}

// ─── Kitsu ───────────────────────────────────────────────────────────────────

/// Kitsu cobre mangá, manhwa, manhua e light novels em UMA requisição e envia
/// `Access-Control-Allow-Origin: *`, então é a única fonte de quadrinhos que
/// funciona no build Web (a MangaDex não responde CORS).
class KitsuManga {
  final String id;
  final String title;
  final List<String> altTitles;
  final String? description;
  final String? posterUrl;
  final String? subtype;
  final int? chapterCount;
  final double? rating;
  final int? userCount;
  final String? year;

  KitsuManga({
    required this.id,
    required this.title,
    this.altTitles = const [],
    this.description,
    this.posterUrl,
    this.subtype,
    this.chapterCount,
    this.rating,
    this.userCount,
    this.year,
  });

  factory KitsuManga.fromJson(Map<String, dynamic> json) {
    final attrs = json['attributes'] as Map<String, dynamic>? ?? const {};
    final titles = (attrs['titles'] as Map<String, dynamic>? ?? const {})
        .values
        .map((v) => v.toString())
        .where((v) => v.trim().isNotEmpty)
        .toList();
    final abbreviated = (attrs['abbreviatedTitles'] as List<dynamic>? ?? const [])
        .map((v) => v.toString())
        .where((v) => v.trim().isNotEmpty)
        .toList();

    final poster = attrs['posterImage'] as Map<String, dynamic>?;

    // Kitsu devolve a nota de 0 a 100; o app usa a escala de 0 a 10.
    final rawRating = _toDouble(attrs['averageRating']);

    return KitsuManga(
      id: json['id']?.toString() ?? '',
      title:
          attrs['canonicalTitle']?.toString() ??
          (titles.isNotEmpty ? titles.first : ''),
      altTitles: {...titles, ...abbreviated}.toList(),
      description:
          attrs['description']?.toString() ?? attrs['synopsis']?.toString(),
      posterUrl:
          poster?['medium']?.toString() ??
          poster?['small']?.toString() ??
          poster?['original']?.toString(),
      subtype: attrs['subtype']?.toString(),
      chapterCount: _toInt(attrs['chapterCount']),
      rating: rawRating == null ? null : rawRating / 10,
      userCount: _toInt(attrs['userCount']),
      year: attrs['startDate']?.toString().split('-').first,
    );
  }

  String get inferredType {
    switch (subtype) {
      case 'manhwa':
        return 'manhwa';
      case 'manhua':
        return 'manhua';
      case 'novel':
      case 'light_novel':
        return 'book';
      default:
        return 'manga';
    }
  }
}

// ─── Resultado unificado de busca ────────────────────────────────────────────

/// Origem do resultado — usada para dedupe e para o selo exibido na UI.
enum SearchSource { catalog, googleBooks, openLibrary, jikan, mangaDex, kitsu }

extension SearchSourceLabel on SearchSource {
  String get label {
    switch (this) {
      case SearchSource.catalog:
        return 'Catálogo';
      case SearchSource.googleBooks:
        return 'Google Books';
      case SearchSource.openLibrary:
        return 'Open Library';
      case SearchSource.jikan:
        return 'MyAnimeList';
      case SearchSource.mangaDex:
        return 'MangaDex';
      case SearchSource.kitsu:
        return 'Kitsu';
    }
  }
}

class SearchResult {
  final String id;
  final String title;
  final String? imageUrl;
  final String? description;
  final List<String>? authors;

  /// 'manga', 'manhwa', 'manhua' ou 'book'.
  final String type;
  final Map<String, dynamic>? rawData;
  final SearchSource source;
  final String? year;
  final double? score;
  final int? totalUnits;
  final List<String>? genres;
  final int popularity;

  /// Títulos alternativos considerados no ranking de relevância.
  final List<String> alternateTitles;

  SearchResult({
    required this.id,
    required this.title,
    this.imageUrl,
    this.description,
    this.authors,
    required this.type,
    this.rawData,
    this.source = SearchSource.catalog,
    this.year,
    this.score,
    this.totalUnits,
    this.genres,
    this.popularity = 0,
    this.alternateTitles = const [],
  });

  bool get isBook => type == 'book';

  String get typeLabel {
    switch (type) {
      case 'manga':
        return 'Mangá';
      case 'manhwa':
        return 'Manhwa';
      case 'manhua':
        return 'Manhua';
      default:
        return 'Livro';
    }
  }

  /// Chave de deduplicação entre fontes diferentes.
  String get dedupeKey {
    final normalized = title
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9À-ſ ]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final family = type == 'book' ? 'book' : 'comic';
    return '$family::$normalized';
  }

  factory SearchResult.fromManga(JikanManga manga) {
    final type = switch (manga.mediaType?.toLowerCase()) {
      'manhwa' => 'manhwa',
      'manhua' => 'manhua',
      _ => 'manga',
    };

    return SearchResult(
      id: 'mal-${manga.malId}',
      title: manga.title,
      imageUrl: manga.imageUrl,
      description: manga.synopsis,
      authors: manga.authors,
      type: type,
      source: SearchSource.jikan,
      year: manga.publishedFrom,
      score: manga.score,
      totalUnits: manga.chapters,
      genres: manga.genres,
      popularity: manga.members ?? 0,
      rawData: {
        'malId': manga.malId,
        'title': manga.title,
        'imageUrl': manga.imageUrl,
        'synopsis': manga.synopsis,
        'authors': manga.authors,
        'status': manga.status,
        'volumes': manga.volumes,
        'chapters': manga.chapters,
        'publishedDate': manga.publishedFrom,
        'genres': manga.genres,
      },
    );
  }

  factory SearchResult.fromBook(
    GoogleBook book, {
    SearchSource source = SearchSource.googleBooks,
  }) {
    return SearchResult(
      id: book.id,
      title: book.title,
      imageUrl: book.imageUrl,
      description: book.description,
      authors: book.authors,
      type: 'book',
      source: source,
      year: book.publishedDate?.split('-').first,
      score: book.averageRating,
      totalUnits: book.pageCount,
      genres: book.categories,
      popularity: book.popularity,
      rawData: {
        'id': book.id,
        'title': book.title,
        'imageUrl': book.imageUrl,
        'description': book.description,
        'authors': book.authors,
        'publishedDate': book.publishedDate,
        'pageCount': book.pageCount,
        'language': book.language,
        'isbn': book.isbn,
        'averageRating': book.averageRating,
        'ratingsCount': book.ratingsCount,
        'wantToReadCount': book.wantToReadCount,
        'alreadyReadCount': book.alreadyReadCount,
        'editionCount': book.editionCount,
        'genres': book.categories,
      },
    );
  }

  factory SearchResult.fromKitsu(KitsuManga manga) {
    return SearchResult(
      id: 'kitsu-${manga.id}',
      title: manga.title,
      imageUrl: manga.posterUrl,
      description: manga.description,
      type: manga.inferredType,
      source: SearchSource.kitsu,
      year: manga.year,
      score: manga.rating,
      totalUnits: manga.chapterCount,
      popularity: manga.userCount ?? 0,
      alternateTitles: manga.altTitles,
      rawData: {
        'id': manga.id,
        'title': manga.title,
        'imageUrl': manga.posterUrl,
        'description': manga.description,
        'publishedDate': manga.year,
        'chapters': manga.chapterCount,
        'pageCount': manga.chapterCount,
      },
    );
  }

  factory SearchResult.fromMangaDex(MangaDexManga manhwa) {
    return SearchResult(
      id: 'mdx-${manhwa.id}',
      title: manhwa.getTitle(),
      imageUrl: manhwa.coverUrl,
      description: manhwa.getDescription(),
      authors: manhwa.authors,
      type: manhwa.inferredType,
      source: SearchSource.mangaDex,
      year: manhwa.year?.toString(),
      totalUnits: manhwa.lastChapter,
      genres: manhwa.tags?.take(6).toList(),
      alternateTitles: manhwa.allTitles,
      rawData: {
        'id': manhwa.id,
        'title': manhwa.getTitle(),
        'imageUrl': manhwa.coverUrl,
        'description': manhwa.getDescription(),
        'authors': manhwa.authors,
        'contentRating': manhwa.contentRating,
        'status': manhwa.status,
        'publicationDemographic': manhwa.publicationDemographic,
        'publishedDate': manhwa.year?.toString(),
        'genres': manhwa.tags,
        'chapters': manhwa.lastChapter,
      },
    );
  }
}
