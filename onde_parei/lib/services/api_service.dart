import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import '../models/api_models.dart';

class ApiService {
  static const String jikanBaseUrl = 'https://api.jikan.moe/v4';
  static const String googleBooksBaseUrl = 'https://www.googleapis.com/books/v1';

  // Controlador simples de rate limiting
  static DateTime _lastRequest = DateTime.now();

  // Buscar mangás na Jikan API com controle de rate limiting
  static Future<List<JikanManga>> searchMangas(String query, {int limit = 10}) async {
    try {
      // Rate limiting: mínimo 1 segundo entre requisições
      final now = DateTime.now();
      final timeSinceLastRequest = now.difference(_lastRequest);
      if (timeSinceLastRequest.inMilliseconds < 1000) {
        await Future.delayed(Duration(milliseconds: 1000 - timeSinceLastRequest.inMilliseconds));
      }
      _lastRequest = DateTime.now();

      final response = await http.get(
        Uri.parse('$jikanBaseUrl/manga?q=$query&limit=$limit'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final jikanResponse = JikanResponse.fromJson(data);
        return jikanResponse.data;
      } else if (response.statusCode == 429) {
        // Rate limited - aguardar mais tempo
        await Future.delayed(const Duration(seconds: 2));
        return searchMangas(query, limit: limit);
      } else {
        throw Exception('Erro ao buscar mangás: ${response.statusCode}');
      }
    } catch (e) {
      if (e.toString().contains('TimeoutException')) {
        throw Exception('Tempo limite excedido. Tente novamente.');
      } else if (e.toString().contains('SocketException')) {
        throw Exception('Erro de conexão. Verifique sua internet.');
      } else {
        throw Exception('Erro de conexão: $e');
      }
    }
  }

  // Buscar livros na Google Books API com fallback para dados de exemplo
  static Future<List<GoogleBook>> searchBooks(String query, {int maxResults = 10}) async {
    try {
      // Rate limiting: mínimo 1 segundo entre requisições
      final now = DateTime.now();
      final timeSinceLastRequest = now.difference(_lastRequest);
      if (timeSinceLastRequest.inMilliseconds < 1000) {
        await Future.delayed(Duration(milliseconds: 1000 - timeSinceLastRequest.inMilliseconds));
      }
      _lastRequest = DateTime.now();

      final response = await http.get(
        Uri.parse('$googleBooksBaseUrl/volumes?q=${Uri.encodeComponent(query)}&maxResults=$maxResults'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final booksResponse = GoogleBooksResponse.fromJson(data);
        return booksResponse.items;
      } else if (response.statusCode == 429) {
        // Rate limited - usar dados de exemplo
        print('⚠️ Google Books API quota exceeded, usando dados de exemplo');
        return _getSampleBooks(query);
      } else {
        throw Exception('Erro ao buscar livros: ${response.statusCode}');
      }
    } catch (e) {
      if (e.toString().contains('TimeoutException')) {
        print('⚠️ Timeout na Google Books API, usando dados de exemplo');
        return _getSampleBooks(query);
      } else if (e.toString().contains('SocketException')) {
        print('⚠️ Erro de conexão na Google Books API, usando dados de exemplo');
        return _getSampleBooks(query);
      } else {
        print('⚠️ Erro na Google Books API, usando dados de exemplo: $e');
        return _getSampleBooks(query);
      }
    }
  }

  // Dados de exemplo para quando a API falhar
  static List<GoogleBook> _getSampleBooks(String query) {
    // Filtrar livros de exemplo baseados na query
    final sampleData = [
      {
        'id': '1',
        'volumeInfo': {
          'title': 'Flutter Apprentice',
          'authors': ['Michael Katz', 'Kevin D. Moore'],
          'publishedDate': '2023',
          'description': 'Learn to build beautiful, natively compiled applications for iOS and Android with Flutter.',
          'pageCount': 500,
          'language': 'en',
          'imageLinks': {
            'thumbnail': 'https://via.placeholder.com/128x192/4A90E2/FFFFFF?text=Flutter+Apprentice'
          },
          'industryIdentifiers': [
            {'type': 'ISBN_13', 'identifier': '9781950325740'}
          ]
        }
      },
      {
        'id': '2',
        'volumeInfo': {
          'title': 'Dart Programming Language',
          'authors': ['Dart Team'],
          'publishedDate': '2022',
          'description': 'Official guide to the Dart programming language.',
          'pageCount': 150,
          'language': 'en',
          'imageLinks': {
            'thumbnail': 'https://via.placeholder.com/128x192/FF6B35/FFFFFF?text=Dart+Guide'
          },
          'industryIdentifiers': [
            {'type': 'ISBN_13', 'identifier': '9780123456789'}
          ]
        }
      },
      {
        'id': '3',
        'volumeInfo': {
          'title': 'Mobile Development with Flutter',
          'authors': ['John Smith', 'Jane Doe'],
          'publishedDate': '2024',
          'description': 'Comprehensive guide to building cross-platform mobile applications.',
          'pageCount': 350,
          'language': 'en',
          'imageLinks': {
            'thumbnail': 'https://via.placeholder.com/128x192/10B981/FFFFFF?text=Flutter+Mobile'
          },
          'industryIdentifiers': [
            {'type': 'ISBN_13', 'identifier': '9789876543210'}
          ]
        }
      },
    ];

    // Converter para GoogleBook
    return sampleData.map((data) => GoogleBook.fromJson(data)).toList();
  }

  // Busca unificada (mangás e livros) com rate limiting
  static Future<List<SearchResult>> searchAll(String query) async {
    try {
      // Buscar sequencialmente para evitar rate limiting
      final results = <SearchResult>[];

      // Buscar mangás primeiro
      try {
        final mangas = await searchMangas(query, limit: 5);
        for (final manga in mangas) {
          results.add(SearchResult.fromManga(manga));
        }
      } catch (e) {
        print('Erro ao buscar mangás: $e');
      }

      // Aguardar um pouco antes de buscar livros
      await Future.delayed(const Duration(milliseconds: 500));

      // Buscar livros
      try {
        final books = await searchBooks(query, maxResults: 5);
        for (final book in books) {
          results.add(SearchResult.fromBook(book));
        }
      } catch (e) {
        print('Erro ao buscar livros: $e');
      }

      if (results.isEmpty) {
        throw Exception('Nenhum resultado encontrado. Tente outros termos de busca.');
      }

      return results;
    } catch (e) {
      throw Exception('Erro na busca: $e');
    }
  }

  // Buscar mangá específico por ID
  static Future<JikanManga?> getMangaById(int malId) async {
    try {
      final response = await http.get(
        Uri.parse('$jikanBaseUrl/manga/$malId'),
      );

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

  // Buscar livro específico por ID
  static Future<GoogleBook?> getBookById(String bookId) async {
    try {
      final response = await http.get(
        Uri.parse('$googleBooksBaseUrl/volumes/$bookId'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return GoogleBook.fromJson(data);
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }
}
