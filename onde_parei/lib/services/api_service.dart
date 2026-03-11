import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import '../models/api_models.dart';
import '../config/api_keys.dart';

class ApiService {
  static const String jikanBaseUrl = 'https://api.jikan.moe/v4';
  static const String openLibraryBaseUrl = 'https://openlibrary.org';
  static const String manhwaManhuaBaseUrl = 'https://api.mangadex.org';
  static const String _googleBooksBaseUrl =
      'https://www.googleapis.com/books/v1';

  // Controlador simples de rate limiting
  static DateTime _lastRequest = DateTime.now();

  // Buscar mang├ís na Jikan API com controle de rate limiting
  static Future<List<JikanManga>> searchMangas(
    String query, {
    int limit = 10,
  }) async {
    try {
      // Rate limiting: m├¡nimo 1 segundo entre requisi├º├Áes
      final now = DateTime.now();
      final timeSinceLastRequest = now.difference(_lastRequest);
      if (timeSinceLastRequest.inMilliseconds < 1000) {
        await Future.delayed(
          Duration(milliseconds: 1000 - timeSinceLastRequest.inMilliseconds),
        );
      }
      _lastRequest = DateTime.now();

      final response = await http
          .get(Uri.parse('$jikanBaseUrl/manga?q=$query&limit=$limit'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final jikanResponse = JikanResponse.fromJson(data);
        return jikanResponse.data;
      } else if (response.statusCode == 429) {
        // Rate limited - aguardar mais tempo
        await Future.delayed(const Duration(seconds: 2));
        return searchMangas(query, limit: limit);
      } else {
        throw Exception('Erro ao buscar mang├ís: ${response.statusCode}');
      }
    } catch (e) {
      if (e.toString().contains('TimeoutException')) {
        throw Exception('Tempo limite excedido. Tente novamente.');
      } else if (e.toString().contains('SocketException')) {
        throw Exception('Erro de conex├úo. Verifique sua internet.');
      } else {
        throw Exception('Erro de conex├úo: $e');
      }
    }
  }

  // Buscar livros na Google Books API (fonte primária)
  static Future<List<GoogleBook>> _searchBooksFromGoogle(
    String query, {
    int maxResults = 10,
  }) async {
    final keyParam = ApiKeys.googleBooks.isNotEmpty
        ? '&key=${ApiKeys.googleBooks}'
        : '';
    final uri = Uri.parse(
      '$_googleBooksBaseUrl/volumes?q=${Uri.encodeComponent(query)}&maxResults=$maxResults&orderBy=relevance$keyParam',
    );
    final response = await http.get(uri).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final googleResponse = GoogleBooksResponse.fromJson(
        data as Map<String, dynamic>,
      );
      return googleResponse.items
          .where((book) => book.title.trim().isNotEmpty)
          .toList();
    } else {
      throw Exception('Google Books: ${response.statusCode}');
    }
  }

  // Buscar livros na Open Library API (fallback)
  static Future<List<GoogleBook>> _searchBooksFromOpenLibrary(
    String query, {
    int maxResults = 10,
  }) async {
    final response = await http
        .get(
          Uri.parse(
            '$openLibraryBaseUrl/search.json?q=${Uri.encodeComponent(query)}&limit=$maxResults',
          ),
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final docs = (data['docs'] as List<dynamic>? ?? []);
      return docs
          .map((doc) => GoogleBook.fromJson(doc as Map<String, dynamic>))
          .where((book) => book.title.trim().isNotEmpty)
          .toList();
    } else {
      throw Exception('Open Library: ${response.statusCode}');
    }
  }

  // Buscar livros — tenta Google Books e cai no Open Library se falhar
  static Future<List<GoogleBook>> searchBooks(
    String query, {
    int maxResults = 10,
  }) async {
    try {
      final results = await _searchBooksFromGoogle(
        query,
        maxResults: maxResults,
      );
      if (results.isNotEmpty) return results;
      // Retornou vazio (sem resultados na GB) → tentar Open Library
      return await _searchBooksFromOpenLibrary(query, maxResults: maxResults);
    } catch (_) {
      // Google Books falhou → fallback para Open Library
      try {
        return await _searchBooksFromOpenLibrary(query, maxResults: maxResults);
      } catch (e) {
        throw Exception('Erro ao buscar livros: $e');
      }
    }
  }

  // Buscar manhwa/manhua na MangaDex API
  static Future<List<MangaDexManga>> searchManhwaManhua(
    String query, {
    int limit = 10,
  }) async {
    try {
      // Rate limiting: m├¡nimo 1 segundo entre requisi├º├Áes
      final now = DateTime.now();
      final timeSinceLastRequest = now.difference(_lastRequest);
      if (timeSinceLastRequest.inMilliseconds < 1000) {
        await Future.delayed(
          Duration(milliseconds: 1000 - timeSinceLastRequest.inMilliseconds),
        );
      }
      _lastRequest = DateTime.now();

      // MangaDex API request
      final response = await http
          .get(
            Uri.parse(
              '$manhwaManhuaBaseUrl/manga?title=$query&includes[]=cover_art&includes[]=author&includes[]=artist&limit=$limit',
            ),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final mangadexResponse = MangaDexResponse.fromJson(data);

        // Buscar covers e authors para cada manga
        final completeMangas = <MangaDexManga>[];
        for (final manga in mangadexResponse.data) {
          final coverUrl = await _getMangaDexCoverUrl(manga.id);
          final authors = await _getMangaDexAuthors(manga.id);

          completeMangas.add(
            MangaDexManga(
              id: manga.id,
              title: manga.title,
              description: manga.description,
              coverUrl: coverUrl,
              authors: authors,
              contentRating: manga.contentRating,
              status: manga.status,
              publicationDemographic: manga.publicationDemographic,
              tags: manga.tags,
            ),
          );
        }

        return completeMangas;
      } else if (response.statusCode == 429) {
        // Rate limited - aguardar mais tempo
        await Future.delayed(const Duration(seconds: 2));
        return searchManhwaManhua(query, limit: limit);
      } else {
        print('MangaDex API error: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Erro ao buscar manhwa/manhua: $e');
      if (e.toString().contains('TimeoutException')) {
        print('ÔÜá´©Å Timeout na MangaDex API');
      } else if (e.toString().contains('SocketException')) {
        print('ÔÜá´©Å Erro de conex├úo na MangaDex API');
      }
      return [];
    }
  }

  // Buscar URL da cover do MangaDex
  static Future<String?> _getMangaDexCoverUrl(String mangaId) async {
    try {
      final response = await http.get(
        Uri.parse('$manhwaManhuaBaseUrl/cover?manga%5B%5D=$mangaId&limit=1'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final covers = data['data'] as List<dynamic>?;
        if (covers != null && covers.isNotEmpty) {
          final filename = covers[0]['attributes']['fileName'];
          return 'https://uploads.mangadex.org/covers/$mangaId/$filename.256.jpg';
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Buscar autores do MangaDex
  static Future<List<Map<String, String>>?> _getMangaDexAuthors(
    String mangaId,
  ) async {
    try {
      final response = await http.get(
        Uri.parse(
          '$manhwaManhuaBaseUrl/manga/$mangaId?includes[]=author&includes[]=artist',
        ),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final authorIds = data['relationships']
            ?.where((rel) => rel['type'] == 'author' || rel['type'] == 'artist')
            ?.map((rel) => rel['id'])
            ?.toSet() // Remove duplicatas
            ?.toList();

        if (authorIds != null && authorIds.isNotEmpty) {
          final authors = <Map<String, String>>[];
          for (final authorId in authorIds) {
            try {
              final authorResponse = await http.get(
                Uri.parse('$manhwaManhuaBaseUrl/author/$authorId'),
              );
              if (authorResponse.statusCode == 200) {
                final authorData = json.decode(authorResponse.body);
                final authorName = authorData['data']['attributes']['name'];
                authors.add({'name': authorName});
              }
            } catch (e) {
              continue;
            }
          }
          return authors;
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Busca unificada PARALELA (mais r├ípida) para melhor UX
  static Future<List<SearchResult>> searchAll(String query) async {
    try {
      // Usar Future.wait para busca PARALELA ao inv├®s de sequencial
      final results = <SearchResult>[];

      final futures = [
        // Buscar mang├ís JAPAN├èS primeiro (Jikan API)
        searchMangas(query, limit: 4)
            .then((mangas) => mangas.map(SearchResult.fromManga).toList())
            .catchError((error) {
              print('Erro ao buscar mang├ís: $error');
              return <SearchResult>[];
            }),

        // Buscar manhwa/manhua PARALELO (MangaDex API) - COREANO/CHIN├èS
        searchManhwaManhua(query, limit: 6)
            .then(
              (manhwaManhua) =>
                  manhwaManhua.map(SearchResult.fromMangaDex).toList(),
            )
            .catchError((error) {
              print('Erro ao buscar manhwa/manhua: $error');
              return <SearchResult>[];
            }),

        // Buscar livros PARALELO
        searchBooks(query, maxResults: 5)
            .then((books) => books.map(SearchResult.fromBook).toList())
            .catchError((error) {
              print('Erro ao buscar livros: $error');
              return <SearchResult>[];
            }),
      ];

      // Aguardar TODAS as buscas terminarem simultaneamente
      final futuresResults = await Future.wait(futures);

      // Combinar todos os resultados
      for (final resultList in futuresResults) {
        results.addAll(resultList);
      }

      if (results.isEmpty) {
        throw Exception(
          'Nenhum resultado encontrado. Tente outros termos de busca.',
        );
      }

      // Ordenar resultados: priorizar LIVROS primeiro e popularidade dos livros
      results.sort((a, b) {
        final order = {'book': 1, 'manga': 2, 'manhwa': 3};
        final typeCompare = (order[a.type] ?? 999).compareTo(
          order[b.type] ?? 999,
        );

        // Tipos diferentes: livros primeiro
        if (typeCompare != 0) return typeCompare;

        // Mesmo tipo 'book': tentar ordenar por popularidade
        if (a.type == 'book') {
          final aRatingsCount = _asInt(a.rawData?['ratingsCount']) ?? 0;
          final bRatingsCount = _asInt(b.rawData?['ratingsCount']) ?? 0;
          if (aRatingsCount != bRatingsCount) {
            return bRatingsCount.compareTo(aRatingsCount);
          }

          final aWantToRead = _asInt(a.rawData?['wantToReadCount']) ?? 0;
          final bWantToRead = _asInt(b.rawData?['wantToReadCount']) ?? 0;
          if (aWantToRead != bWantToRead) {
            return bWantToRead.compareTo(aWantToRead);
          }

          final aAlreadyRead = _asInt(a.rawData?['alreadyReadCount']) ?? 0;
          final bAlreadyRead = _asInt(b.rawData?['alreadyReadCount']) ?? 0;
          if (aAlreadyRead != bAlreadyRead) {
            return bAlreadyRead.compareTo(aAlreadyRead);
          }

          final aEditionCount = _asInt(a.rawData?['editionCount']) ?? 0;
          final bEditionCount = _asInt(b.rawData?['editionCount']) ?? 0;
          if (aEditionCount != bEditionCount) {
            return bEditionCount.compareTo(aEditionCount);
          }

          final aAverageRating = _asDouble(a.rawData?['averageRating']) ?? 0;
          final bAverageRating = _asDouble(b.rawData?['averageRating']) ?? 0;
          if (aAverageRating != bAverageRating) {
            return bAverageRating.compareTo(aAverageRating);
          }
        }

        return a.title.toLowerCase().compareTo(b.title.toLowerCase());
      });

      return results;
    } catch (e) {
      throw Exception('Erro na busca: $e');
    }
  }

  static int? _asInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static double? _asDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  // Buscar mang├í espec├¡fico por ID
  static Future<JikanManga?> getMangaById(int malId) async {
    try {
      final response = await http.get(Uri.parse('$jikanBaseUrl/manga/$malId'));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final mangaData = data['data'];
        return JikanManga.fromJson(mangaData);
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  // Buscar livro espec├¡fico por ID (Open Library work id)
  static Future<GoogleBook?> getBookById(String bookId) async {
    try {
      final response = await http.get(
        Uri.parse('$openLibraryBaseUrl/works/$bookId.json'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return GoogleBook.fromJson({
          'key': '/works/$bookId',
          'title': data['title']?.toString() ?? '',
          'first_publish_year': data['first_publish_date']?.toString(),
          'description': data['description'] is Map
              ? data['description']['value']?.toString()
              : data['description']?.toString(),
        });
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }
}
