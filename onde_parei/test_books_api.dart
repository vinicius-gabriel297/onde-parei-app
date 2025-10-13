import 'dart:convert';
import 'package:http/http.dart' as http;

// Modelos para teste direto da API Google Books
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

void main() async {
  print('🧪 Iniciando teste da API Google Books...');

  try {
    // URL da API Google Books para buscar livros
    final url = 'https://www.googleapis.com/books/v1/volumes?q=flutter&maxResults=5';

    print('📡 Fazendo requisição para: $url');

    final response = await http.get(
      Uri.parse(url),
    ).timeout(const Duration(seconds: 10));

    print('📊 Status Code: ${response.statusCode}');
    print('📋 Headers: ${response.headers}');
    print('📝 Body length: ${response.body.length}');

    if (response.statusCode == 200) {
      final data = json.decode(response.body);

      print('🎯 Dados recebidos:');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      final booksResponse = GoogleBooksResponse.fromJson(data);

      print('📚 Total de livros encontrados: ${booksResponse.items.length}');

      for (int i = 0; i < booksResponse.items.length; i++) {
        final book = booksResponse.items[i];
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        print('📖 Livro #${i + 1}:');
        print('📚 Título: ${book.title}');
        print('🆔 ID: ${book.id}');
        print('🖼️  Imagem: ${book.imageUrl ?? 'N/A'}');
        print('✍️  Autores: ${book.authors?.join(', ') ?? 'N/A'}');
        print('📅 Data de publicação: ${book.publishedDate ?? 'N/A'}');
        print('📄 Número de páginas: ${book.pageCount ?? 'N/A'}');
        print('🌐 Idioma: ${book.language ?? 'N/A'}');
        print('📊 ISBN: ${book.isbn ?? 'N/A'}');
        if (book.description != null && book.description!.length > 100) {
          print('📝 Descrição: ${book.description!.substring(0, 100)}...');
        } else {
          print('📝 Descrição: ${book.description ?? 'N/A'}');
        }
      }

      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('✅ Teste concluído com sucesso!');
      print('🎯 Dados podem ser usados no aplicativo');

    } else {
      print('❌ Erro na API:');
      print('Status: ${response.statusCode}');
      print('Body: ${response.body}');
    }

  } catch (e) {
    print('🚨 Erro durante o teste: $e');

    if (e.toString().contains('TimeoutException')) {
      print('💡 Possível causa: Timeout na requisição');
    } else if (e.toString().contains('SocketException')) {
      print('💡 Possível causa: Problema de conexão de rede');
    } else {
      print('💡 Possível causa: Erro desconhecido');
    }
  }

  print('🔚 Teste finalizado');
}
