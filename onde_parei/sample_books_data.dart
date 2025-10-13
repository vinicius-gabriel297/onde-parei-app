// Arquivo com dados de exemplo de livros para teste
// Estes dados representam o formato que a API Google Books retornaria

final List<Map<String, dynamic>> sampleBooksData = [
  {
    'id': '1',
    'volumeInfo': {
      'title': 'Flutter Apprentice',
      'authors': ['Michael Katz', 'Kevin D. Moore'],
      'publishedDate': '2023',
      'description': 'Learn to build beautiful, natively compiled applications for iOS and Android with Flutter, Google\'s revolutionary mobile development framework.',
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
      'description': 'Official guide to the Dart programming language, the foundation of Flutter development.',
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
      'description': 'Comprehensive guide to building cross-platform mobile applications using Flutter and Dart.',
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
  {
    'id': '4',
    'volumeInfo': {
      'title': 'Firebase and Flutter Integration',
      'authors': ['Firebase Team', 'Flutter Developers'],
      'publishedDate': '2023',
      'description': 'Learn how to integrate Firebase services with Flutter applications for authentication, database, and more.',
      'pageCount': 280,
      'language': 'en',
      'imageLinks': {
        'thumbnail': 'https://via.placeholder.com/128x192/F59E0B/FFFFFF?text=Firebase+Flutter'
      },
      'industryIdentifiers': [
        {'type': 'ISBN_13', 'identifier': '9781111222334'}
      ]
    }
  },
  {
    'id': '5',
    'volumeInfo': {
      'title': 'Advanced Flutter Techniques',
      'authors': ['Senior Flutter Developer'],
      'publishedDate': '2024',
      'description': 'Master advanced Flutter concepts including custom widgets, animations, and performance optimization.',
      'pageCount': 420,
      'language': 'en',
      'imageLinks': {
        'thumbnail': 'https://via.placeholder.com/128x192/8B5CF6/FFFFFF?text=Advanced+Flutter'
      },
      'industryIdentifiers': [
        {'type': 'ISBN_13', 'identifier': '9785555666777'}
      ]
    }
  },
];

void main() {
  print('📚 Dados de exemplo de livros (Google Books API):');
  print('Total de itens: ${sampleBooksData.length}');

  for (int i = 0; i < sampleBooksData.length; i++) {
    final book = sampleBooksData[i];
    final volumeInfo = book['volumeInfo'];

    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('📖 Livro #${i + 1}: ${volumeInfo['title']}');
    print('🆔 ID: ${book['id']}');
    print('✍️  Autores: ${(volumeInfo['authors'] as List?)?.join(', ') ?? 'N/A'}');
    print('📅 Publicado: ${volumeInfo['publishedDate']}');
    print('📄 Páginas: ${volumeInfo['pageCount']}');
    print('🌐 Idioma: ${volumeInfo['language']}');
    print('📊 ISBN: ${(volumeInfo['industryIdentifiers'] as List?)?.firstWhere((id) => id['type'] == 'ISBN_13', orElse: () => {'identifier': 'N/A'})['identifier']}');
    if (volumeInfo['description'] != null && volumeInfo['description'].length > 80) {
      print('📝 Descrição: ${volumeInfo['description'].substring(0, 80)}...');
    }
  }

  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  print('✅ Dados prontos para uso no aplicativo!');
  print('💡 Nota: Estes são dados de exemplo. A API real retorna dados similares.');
}
