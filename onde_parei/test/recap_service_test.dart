import 'package:flutter_test/flutter_test.dart';
import 'package:onde_parei/models/item_model.dart';
import 'package:onde_parei/services/recap_service.dart';

ItemModel _item({
  String name = 'Obra',
  ItemType type = ItemType.book,
  ReadingStatus status = ReadingStatus.read,
  double rating = 0,
  String totalPages = '',
  String totalChapters = '',
  List<String>? genres,
  DateTime? startedAt,
  DateTime? finishedAt,
}) {
  final now = DateTime(2026, 1, 1);
  return ItemModel(
    id: name,
    userId: 'user-1',
    name: name,
    type: type,
    status: status,
    currentChapter: '',
    currentPage: '',
    totalPages: totalPages,
    totalChapters: totalChapters,
    rating: rating,
    genres: genres,
    startedAt: startedAt,
    finishedAt: finishedAt,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('datas por status', () {
    final now = DateTime(2026, 5, 10);

    test('marcar "lendo" registra o início e limpa o fim', () {
      final dates = ItemModel.datesFor(
        status: ReadingStatus.reading,
        finishedAt: DateTime(2026, 1, 1),
        now: now,
      );

      expect(dates.startedAt, now);
      expect(dates.finishedAt, isNull);
    });

    test('marcar "lido" registra o fim e preserva o início', () {
      final start = DateTime(2026, 4, 1);
      final dates = ItemModel.datesFor(
        status: ReadingStatus.read,
        startedAt: start,
        now: now,
      );

      expect(dates.startedAt, start);
      expect(dates.finishedAt, now);
    });

    test('data já preenchida à mão não é sobrescrita', () {
      final start = DateTime(2025, 2, 3);
      final end = DateTime(2025, 3, 4);
      final dates = ItemModel.datesFor(
        status: ReadingStatus.read,
        startedAt: start,
        finishedAt: end,
        now: now,
      );

      expect(dates.startedAt, start);
      expect(dates.finishedAt, end);
    });

    test('voltar para "quero ler" apaga as duas', () {
      final dates = ItemModel.datesFor(
        status: ReadingStatus.wantToRead,
        startedAt: DateTime(2026, 1, 1),
        finishedAt: DateTime(2026, 2, 1),
        now: now,
      );

      expect(dates.startedAt, isNull);
      expect(dates.finishedAt, isNull);
    });

    test('"em pausa" mantém o início e derruba o fim', () {
      final start = DateTime(2026, 1, 5);
      final dates = ItemModel.datesFor(
        status: ReadingStatus.paused,
        startedAt: start,
        finishedAt: DateTime(2026, 2, 1),
        now: now,
      );

      expect(dates.startedAt, start);
      expect(dates.finishedAt, isNull);
    });

    test('aplicar duas vezes dá o mesmo resultado', () {
      final first = ItemModel.datesFor(status: ReadingStatus.read, now: now);
      final second = ItemModel.datesFor(
        status: ReadingStatus.read,
        startedAt: first.startedAt,
        finishedAt: first.finishedAt,
        now: DateTime(2026, 12, 31),
      );

      expect(second.finishedAt, first.finishedAt);
    });
  });

  group('duração da leitura', () {
    test('mesmo dia conta como um dia', () {
      final item = _item(
        startedAt: DateTime(2026, 3, 4, 8),
        finishedAt: DateTime(2026, 3, 4, 23),
      );

      expect(item.readingDays, 1);
    });

    test('sem uma das datas não há duração', () {
      expect(_item(startedAt: DateTime(2026, 3, 4)).readingDays, isNull);
    });
  });

  group('retrospectiva do ano', () {
    final items = <ItemModel>[
      _item(
        name: 'Duna',
        rating: 5,
        totalPages: '600',
        genres: const ['Ficção científica', 'Aventura'],
        startedAt: DateTime(2026, 1, 10),
        finishedAt: DateTime(2026, 1, 20),
      ),
      _item(
        name: 'Berserk',
        type: ItemType.manga,
        rating: 4,
        totalChapters: '374',
        genres: const ['Aventura'],
        finishedAt: DateTime(2026, 1, 25),
      ),
      _item(
        name: 'Neuromancer',
        rating: 3,
        totalPages: '300',
        genres: const ['Ficção científica'],
        finishedAt: DateTime(2026, 7, 2),
      ),
      // Fora do ano.
      _item(name: 'Antigo', rating: 5, finishedAt: DateTime(2025, 6, 1)),
      // Lido, mas sem data — item de antes desta versão.
      _item(name: 'Sem data', rating: 5),
      // Em andamento não conta.
      _item(
        name: 'Em curso',
        status: ReadingStatus.reading,
        startedAt: DateTime(2026, 2, 1),
      ),
    ];

    final recap = ReadingRecap.forYear(items, 2026);

    test('conta só o que terminou no ano com data', () {
      expect(recap.total, 3);
      expect(recap.books, 2);
      expect(recap.comics, 1);
    });

    test('separa páginas de capítulos', () {
      expect(recap.pages, 900);
      expect(recap.chapters, 374);
    });

    test('distribui por mês e aponta o mês mais forte', () {
      expect(recap.countIn(1), 2);
      expect(recap.countIn(7), 1);
      expect(recap.countIn(3), 0);
      expect(recap.busiestMonth, 1);
    });

    test('a favorita é a de maior nota', () {
      expect(recap.favorite?.name, 'Duna');
      expect(recap.averageRating, closeTo(4, 0.001));
    });

    test('gêneros vêm ordenados por frequência, e o empate pelo nome', () {
      // Aventura e Ficção científica aparecem duas vezes cada — a ordem
      // alfabética é o desempate, para a lista não dançar entre builds.
      expect(
        recap.topGenres.map((g) => '${g.genre}:${g.count}').toList(),
        ['Aventura:2', 'Ficção científica:2'],
      );
    });

    test('média de dias usa só quem tem as duas datas', () {
      expect(recap.averageDays, 11);
    });

    test('ano sem leitura fica vazio, mas continua utilizável', () {
      final vazio = ReadingRecap.forYear(items, 2024);

      expect(vazio.isEmpty, isTrue);
      expect(vazio.busiestMonth, isNull);
      expect(vazio.favorite, isNull);
      expect(vazio.countIn(6), 0);
    });

    test('os anos disponíveis incluem o atual e vêm do mais novo', () {
      final years = ReadingRecap.availableYears(
        items,
        now: DateTime(2027, 3, 1),
      );

      expect(years, [2027, 2026, 2025]);
    });
  });

  group('cápsula mensal', () {
    final items = <ItemModel>[
      _item(
        name: 'Duna',
        rating: 5,
        totalPages: '600',
        genres: const ['Ficção científica'],
        startedAt: DateTime(2026, 9, 1),
        finishedAt: DateTime(2026, 9, 10),
      ),
      _item(
        name: 'Noites brancas',
        rating: 4,
        totalPages: '120',
        finishedAt: DateTime(2026, 9, 20),
      ),
      _item(name: 'Mistborn', rating: 3, finishedAt: DateTime(2026, 8, 5)),
    ];

    test('o mês recorta só o que terminou dentro dele', () {
      final setembro = ReadingRecap.forMonth(items, 2026, 9);

      expect(setembro.total, 2);
      expect(setembro.pages, 720);
      expect(setembro.favorite?.name, 'Duna');
      expect(setembro.isMonthly, isTrue);
      expect(setembro.periodLabel, 'setembro de 2026');
    });

    test('o ano continua somando todos os meses', () {
      final ano = ReadingRecap.forYear(items, 2026);

      expect(ano.total, 3);
      expect(ano.isMonthly, isFalse);
      expect(ano.periodLabel, '2026');
    });

    test('os meses com leitura vêm do mais recente', () {
      expect(ReadingRecap.monthsWithReadings(items, 2026), [9, 8]);
      expect(ReadingRecap.monthsWithReadings(items, 2025), isEmpty);
    });

    test('mês sem leitura fica vazio, mas continua utilizável', () {
      final marco = ReadingRecap.forMonth(items, 2026, 3);

      expect(marco.isEmpty, isTrue);
      expect(marco.favorite, isNull);
      expect(marco.periodLabel, 'março de 2026');
    });
  });
}
