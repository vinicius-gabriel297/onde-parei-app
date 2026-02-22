import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/reading_item.dart';

class ApiService {
  static const String mangaApiBaseUrl = 'https://api.jikan.moe/v4';
  static const String bookApiBaseUrl = 'https://openlibrary.org';
  static const String openLibraryCoversBaseUrl =
      'https://covers.openlibrary.org/b/id';

  Future<List<Map<String, dynamic>>> searchManga(String query) async {
    try {
      final response = await http.get(
        Uri.parse('$mangaApiBaseUrl/manga?q=$query&limit=20'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['data'] ?? []);
      } else {
        throw Exception('Erro na busca de mangá: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Erro de conexão: $e');
    }
  }

  Future<List<Map<String, dynamic>>> searchBooks(String query) async {
    if (query.trim().isEmpty) {
      return [];
    }

    final uri = Uri.parse(
      '$bookApiBaseUrl/search.json',
    ).replace(queryParameters: {'q': query, 'limit': '20'});

    try {
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['docs'] ?? []);
      } else {
        throw Exception('Erro na busca de livros: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Erro de conexão na busca de livros: $e');
    }
  }

  ReadingItem mangaFromApi(Map<String, dynamic> mangaData) {
    return ReadingItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userId: '', // Será definido quando o usuário adicionar
      title: mangaData['title'] ?? 'Título desconhecido',
      imageUrl: mangaData['images']?['jpg']?['large_image_url'] ??
          mangaData['images']?['jpg']?['image_url'] ??
          mangaData['images']?['jpg']?['small_image_url'],
      type: ItemType.manga,
      status: ReadingStatus.pretendeRer,
      currentChapter: 0,
      totalChapters: mangaData['chapters'],
      rating: 0.0,
      addedAt: DateTime.now(),
      updatedAt: DateTime.now(),
      apiId: mangaData['mal_id'].toString(),
      author: mangaData['authors']?.isNotEmpty == true
          ? mangaData['authors'][0]['name']
          : null,
      description: mangaData['synopsis'],
    );
  }

  ReadingItem bookFromApi(Map<String, dynamic> bookData) {
    final coverId = bookData['cover_i'];
    String? imageUrl;

    if (coverId != null) {
      imageUrl = '$openLibraryCoversBaseUrl/$coverId-L.jpg';
    }

    final authors = (bookData['author_name'] as List?)?.cast<String>();
    final author =
        (authors != null && authors.isNotEmpty) ? authors.first : null;

    final firstSentence = bookData['first_sentence'];
    String? description;

    if (firstSentence is String && firstSentence.trim().isNotEmpty) {
      description = firstSentence;
    } else if (firstSentence is List && firstSentence.isNotEmpty) {
      description = firstSentence.first.toString();
    }

    return ReadingItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userId: '', // Será definido quando o usuário adicionar
      title: bookData['title'] ?? 'Título desconhecido',
      imageUrl: imageUrl,
      type: ItemType.book,
      status: ReadingStatus.pretendeRer,
      currentChapter: 0,
      totalChapters: bookData['number_of_pages_median'],
      rating: 0.0,
      addedAt: DateTime.now(),
      updatedAt: DateTime.now(),
      apiId: bookData['key'],
      author: author,
      description: description,
    );
  }
}
