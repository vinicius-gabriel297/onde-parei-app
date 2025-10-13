// Modelos para Jikan API (Mangás)
class JikanManga {
  final int malId;
  final String title;
  final String? imageUrl;
  final String? synopsis;
  final List<String>? authors;
  final String? status;
  final int? volumes;
  final int? chapters;

  JikanManga({
    required this.malId,
    required this.title,
    this.imageUrl,
    this.synopsis,
    this.authors,
    this.status,
    this.volumes,
    this.chapters,
  });

  factory JikanManga.fromJson(Map<String, dynamic> json) {
    return JikanManga(
      malId: json['mal_id'] ?? 0,
      title: json['title'] ?? '',
      imageUrl: json['images']?['jpg']?['large_image_url'],
      synopsis: json['synopsis'],
      authors: json['authors']?.map<String>((author) => author['name'].toString()).toList(),
      status: json['status'],
      volumes: json['volumes'],
      chapters: json['chapters'],
    );
  }
}

class JikanResponse {
  final List<JikanManga> data;

  JikanResponse({required this.data});

  factory JikanResponse.fromJson(Map<String, dynamic> json) {
    return JikanResponse(
      data: (json['data'] as List<dynamic>?)
          ?.map((item) => JikanManga.fromJson(item))
          .toList() ?? [],
    );
  }
}

// Modelos para Google Books API (Livros)
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
  });

  factory GoogleBook.fromJson(Map<String, dynamic> json) {
    final volumeInfo = json['volumeInfo'];

    return GoogleBook(
      id: json['id'] ?? '',
      title: volumeInfo?['title'] ?? '',
      imageUrl: volumeInfo?['imageLinks']?['thumbnail']?.replaceFirst('http:', 'https:'),
      description: volumeInfo?['description'],
      authors: volumeInfo?['authors']?.cast<String>(),
      publishedDate: volumeInfo?['publishedDate'],
      pageCount: volumeInfo?['pageCount'],
      language: volumeInfo?['language'],
      isbn: _extractIsbn(volumeInfo),
    );
  }

  static String? _extractIsbn(Map<String, dynamic>? volumeInfo) {
    if (volumeInfo == null) return null;

    final identifiers = volumeInfo['industryIdentifiers'] as List<dynamic>?;
    if (identifiers == null) return null;

    for (var identifier in identifiers) {
      if (identifier['type'] == 'ISBN_13' || identifier['type'] == 'ISBN_10') {
        return identifier['identifier'];
      }
    }
    return null;
  }
}

class GoogleBooksResponse {
  final List<GoogleBook> items;
  final int totalItems;

  GoogleBooksResponse({
    required this.items,
    required this.totalItems,
  });

  factory GoogleBooksResponse.fromJson(Map<String, dynamic> json) {
    return GoogleBooksResponse(
      items: (json['items'] as List<dynamic>?)
          ?.map((item) => GoogleBook.fromJson(item))
          .toList() ?? [],
      totalItems: json['totalItems'] ?? 0,
    );
  }
}

// Modelos para MangaDex API (Manhwa/Manhua)
class MangaDexManga {
  final String id;
  final Map<String, String> title;
  final Map<String, String>? description;
  final String? coverUrl;
  final List<Map<String, String>>? authors;
  final String? contentRating;
  final String? status;
  final String? publicationDemographic;
  final List<String>? tags;

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
  });

  factory MangaDexManga.fromJson(Map<String, dynamic> json) {
    return MangaDexManga(
      id: json['id'] ?? '',
      title: (json['attributes']?['title'] as Map<String, dynamic>?)?.cast<String, String>() ?? {},
      description: (json['attributes']?['description'] as Map<String, dynamic>?)?.cast<String, String>(),
      contentRating: json['attributes']?['contentRating'],
      status: json['attributes']?['status'],
      publicationDemographic: json['attributes']?['publicationDemographic'],
      tags: json['attributes']?['tags']?.map<String>((tag) => tag['attributes']['name']['en'] as String).toList(),
      // Authors e cover serão populados posteriormente se necessário
    );
  }

  String getTitle() => title['en'] ?? title.entries.first.value;
  String? getDescription() => description?['en'] ?? description?.entries.first.value;
}

class MangaDexResponse {
  final List<MangaDexManga> data;
  final int total;

  MangaDexResponse({required this.data, required this.total});

  factory MangaDexResponse.fromJson(Map<String, dynamic> json) {
    return MangaDexResponse(
      data: (json['data'] as List<dynamic>?)
          ?.map((item) => MangaDexManga.fromJson(item))
          .toList() ?? [],
      total: json['total'] ?? 0,
    );
  }
}

// Modelo para busca unificada
class SearchResult {
  final String id;
  final String title;
  final String? imageUrl;
  final String? description;
  final List<String>? authors;
  final String type; // 'manga', 'manhwa', 'book'
  final Map<String, dynamic>? rawData;

  SearchResult({
    required this.id,
    required this.title,
    this.imageUrl,
    this.description,
    this.authors,
    required this.type,
    this.rawData,
  });

  factory SearchResult.fromManga(JikanManga manga) {
    return SearchResult(
      id: manga.malId.toString(),
      title: manga.title,
      imageUrl: manga.imageUrl,
      description: manga.synopsis,
      authors: manga.authors,
      type: 'manga',
      rawData: {
        'malId': manga.malId,
        'title': manga.title,
        'imageUrl': manga.imageUrl,
        'synopsis': manga.synopsis,
        'authors': manga.authors,
        'status': manga.status,
        'volumes': manga.volumes,
        'chapters': manga.chapters,
      },
    );
  }

  factory SearchResult.fromBook(GoogleBook book) {
    return SearchResult(
      id: book.id,
      title: book.title,
      imageUrl: book.imageUrl,
      description: book.description,
      authors: book.authors,
      type: 'book',
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
      },
    );
  }

  factory SearchResult.fromMangaDex(MangaDexManga manhwa) {
    return SearchResult(
      id: manhwa.id,
      title: manhwa.getTitle(),
      imageUrl: manhwa.coverUrl,
      description: manhwa.getDescription(),
      authors: manhwa.authors?.map((author) => author['name'] ?? 'Desconhecido').toList(),
      type: 'manhwa', // or 'manhua' based on tags/demographic
      rawData: {
        'id': manhwa.id,
        'title': manhwa.title,
        'description': manhwa.description,
        'contentRating': manhwa.contentRating,
        'status': manhwa.status,
        'publicationDemographic': manhwa.publicationDemographic,
        'tags': manhwa.tags,
      },
    );
  }
}
