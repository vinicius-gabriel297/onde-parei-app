import 'package:flutter_test/flutter_test.dart';
import 'package:onde_parei/models/api_models.dart';
import 'package:onde_parei/models/item_model.dart';
import 'package:onde_parei/services/api_service.dart';

void main() {
  group('MangaDex', () {
    test('extrai capa e autores de relationships sem requisições extras', () {
      final manga = MangaDexManga.fromJson({
        'id': 'abc-123',
        'attributes': {
          'title': {'en': 'Solo Leveling'},
          'description': {'en': 'Um caçador fraco fica muito forte.'},
          'originalLanguage': 'ko',
          'year': 2018,
          'lastChapter': '200',
          'status': 'completed',
          'tags': [
            {
              'attributes': {
                'name': {'en': 'Action'},
              },
            },
          ],
        },
        'relationships': [
          {
            'type': 'author',
            'attributes': {'name': 'Chugong (추공)'},
          },
          {
            'type': 'artist',
            'attributes': {'name': 'Jang Sung-Rak'},
          },
          {
            'type': 'cover_art',
            'attributes': {'fileName': 'cover.jpg'},
          },
        ],
      });

      expect(manga.getTitle(), 'Solo Leveling');
      expect(manga.authors, ['Chugong', 'Jang Sung-Rak']);
      expect(
        manga.coverUrl,
        'https://uploads.mangadex.org/covers/abc-123/cover.jpg.512.jpg',
      );
      expect(manga.inferredType, 'manhwa');
      expect(manga.lastChapter, 200);
      expect(manga.tags, ['Action']);
    });

    test('prefere descrição em pt-br quando existe', () {
      final manga = MangaDexManga.fromJson({
        'id': 'x',
        'attributes': {
          'title': {'ja-ro': 'Berserk'},
          'description': {'en': 'English', 'pt-br': 'Português'},
        },
        'relationships': const [],
      });

      expect(manga.getDescription(), 'Português');
    });
  });

  group('Ranking de busca', () {
    SearchResult make(String title, {int popularity = 0}) => SearchResult(
      id: title,
      title: title,
      type: 'book',
      popularity: popularity,
      imageUrl: 'https://example.com/$title.jpg',
    );

    test('coloca o título exato na frente de um popular irrelevante', () {
      final ranked = ApiService.rank([
        make('Guia ilustrado sobre duna e deserto', popularity: 90000),
        make('Duna'),
      ], 'duna');

      expect(ranked.first.title, 'Duna');
    });

    test('ignora acentos e maiúsculas', () {
      final ranked = ApiService.rank([
        make('Outro livro qualquer'),
        make('A Revolução dos Bichos'),
      ], 'revolucao dos bichos');

      expect(ranked.first.title, 'A Revolução dos Bichos');
    });
  });

  group('Kitsu', () {
    test('mapeia subtype, nota 0-100 e capa', () {
      final manga = KitsuManga.fromJson({
        'id': '54114',
        'attributes': {
          'canonicalTitle': 'Solo Leveling',
          'titles': {'en_us': 'Solo Leveling', 'en_kr': 'Na Honjaman Level Up'},
          'abbreviatedTitles': ['SL'],
          'description': 'Um caçador fraco fica muito forte.',
          'posterImage': {'medium': 'https://media.kitsu.app/p/medium.jpg'},
          'subtype': 'manhwa',
          'chapterCount': 201,
          'averageRating': '84.52',
          'userCount': 57317,
          'startDate': '2018-03-04',
        },
      });

      expect(manga.inferredType, 'manhwa');
      expect(manga.rating, closeTo(8.452, 0.001));
      expect(manga.chapterCount, 201);
      expect(manga.year, '2018');
      expect(manga.altTitles, contains('Na Honjaman Level Up'));
      expect(manga.posterUrl, 'https://media.kitsu.app/p/medium.jpg');
    });

    test('light novel entra como livro', () {
      final manga = KitsuManga.fromJson({
        'id': '1',
        'attributes': {'canonicalTitle': 'Overlord', 'subtype': 'novel'},
      });
      expect(manga.inferredType, 'book');
    });
  });

  group('Dedupe', () {
    test('mesma obra em fontes diferentes compartilha a chave', () {
      final a = SearchResult(id: '1', title: 'Solo Leveling', type: 'manhwa');
      final b = SearchResult(id: '2', title: 'solo leveling!', type: 'manga');
      expect(a.dedupeKey, b.dedupeKey);
    });

    test('livro e quadrinho de mesmo nome não colidem', () {
      final a = SearchResult(id: '1', title: 'Berserk', type: 'manga');
      final b = SearchResult(id: '2', title: 'Berserk', type: 'book');
      expect(a.dedupeKey, isNot(b.dedupeKey));
    });
  });

  group('Ranking com títulos alternativos', () {
    test('título exibido ganha de apelido escondido', () {
      final ranked = ApiService.rank([
        SearchResult(
          id: 'apelido',
          title: 'Only I Level Up',
          type: 'book',
          alternateTitles: const ['Solo Leveling'],
          popularity: 5000,
          imageUrl: 'https://example.com/a.jpg',
        ),
        SearchResult(
          id: 'principal',
          title: 'Solo Leveling',
          type: 'manhwa',
          imageUrl: 'https://example.com/b.jpg',
        ),
      ], 'solo leveling');

      expect(ranked.first.id, 'principal');
    });

    test('produtos derivados ficam atrás da obra', () {
      final ranked = ApiService.rank([
        SearchResult(
          id: 'derivado',
          title: 'One Piece Coloring Book',
          type: 'book',
          popularity: 900,
          imageUrl: 'https://example.com/a.jpg',
        ),
        SearchResult(
          id: 'obra',
          title: 'One Piece',
          type: 'manga',
          imageUrl: 'https://example.com/b.jpg',
        ),
      ], 'one piece');

      expect(ranked.first.id, 'obra');
    });
  });

  group('ItemModel', () {
    ItemModel build({
      required ItemType type,
      String currentChapter = '',
      String totalChapters = '',
      String currentPage = '',
      String totalPages = '',
      ReadingStatus status = ReadingStatus.reading,
    }) => ItemModel(
      id: '1',
      userId: 'u',
      name: 'Teste',
      type: type,
      status: status,
      currentChapter: currentChapter,
      currentPage: currentPage,
      totalChapters: totalChapters,
      totalPages: totalPages,
      rating: 0,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

    test('calcula progresso por capítulos', () {
      final item = build(
        type: ItemType.manhwa,
        currentChapter: '50',
        totalChapters: '200',
      );
      expect(item.progress, closeTo(0.25, 0.001));
      expect(item.displayCurrentPosition, 'Capítulo 50 de 200');
    });

    test('sem total não há progresso', () {
      final item = build(type: ItemType.book, currentPage: '30');
      expect(item.progress, isNull);
      expect(item.displayCurrentPosition, 'Página 30');
    });

    test('item lido conta como 100%', () {
      final item = build(type: ItemType.book, status: ReadingStatus.read);
      expect(item.progress, 1);
    });
  });
}
