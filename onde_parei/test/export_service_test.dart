import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:onde_parei/models/item_model.dart';
import 'package:onde_parei/services/export_service.dart';

ItemModel _item({
  String name = 'Berserk',
  ItemType type = ItemType.manga,
  ReadingStatus status = ReadingStatus.reading,
  String currentChapter = '364',
  double rating = 5,
  String review = '',
  String? author = 'Kentaro Miura',
  List<String>? genres = const ['Ação', 'Fantasia'],
  String? externalId,
  String? source,
}) {
  final now = DateTime.utc(2026, 8, 31, 12);
  return ItemModel(
    id: 'abc123',
    userId: 'user-1',
    name: name,
    type: type,
    status: status,
    currentChapter: currentChapter,
    currentPage: '',
    rating: rating,
    review: review,
    author: author,
    genres: genres,
    externalId: externalId,
    source: source,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('buildJson', () {
    test('inclui conta, contagem e itens em formato relido sem perda', () {
      final json = ExportService.buildJson(
        userId: 'user-1',
        email: 'leitor@exemplo.com',
        displayName: 'Leitor',
        items: [_item()],
      );

      final decoded = jsonDecode(json) as Map<String, dynamic>;

      expect(decoded['formatVersion'], ExportService.jsonFormatVersion);
      expect(decoded['itemCount'], 1);
      expect(
        (decoded['account'] as Map<String, dynamic>)['email'],
        'leitor@exemplo.com',
      );

      final first = (decoded['items'] as List).first as Map<String, dynamic>;
      expect(first['name'], 'Berserk');
      // Nomes de enum, não índices: o arquivo continua legível se a ordem mudar.
      expect(first['type'], 'manga');
      expect(first['status'], 'reading');
      expect(first['currentChapter'], '364');
      expect(first['genres'], ['Ação', 'Fantasia']);
    });

    test('leva o vínculo com a origem, e nulo quando o item foi digitado', () {
      final json = ExportService.buildJson(
        userId: 'user-1',
        items: [
          _item(externalId: 'mal-2', source: 'jikan'),
          _item(name: 'Anotado à mão'),
        ],
      );

      final items = (jsonDecode(json) as Map<String, dynamic>)['items'] as List;
      final vindoDaBusca = items.first as Map<String, dynamic>;
      final digitado = items.last as Map<String, dynamic>;

      expect(vindoDaBusca['source'], 'jikan');
      expect(vindoDaBusca['externalId'], 'mal-2');
      expect(digitado['source'], isNull);
      expect(digitado['externalId'], isNull);
    });

    test('estante vazia gera arquivo válido', () {
      final decoded =
          jsonDecode(ExportService.buildJson(userId: 'user-1', items: const []))
              as Map<String, dynamic>;
      expect(decoded['itemCount'], 0);
      expect(decoded['items'], isEmpty);
    });
  });

  group('buildCsv', () {
    test('escapa vírgula, aspas e quebra de linha', () {
      final csv = ExportService.buildCsv([
        _item(name: 'Título com, vírgula', author: 'Autor "citado"'),
      ]);

      final lines = const LineSplitter().convert(csv);
      expect(lines.first, startsWith('﻿nome,tipo,status'));
      expect(lines[1], contains('"Título com, vírgula"'));
      expect(lines[1], contains('"Autor ""citado"""'));
      // Gêneros são achatados com ponto e vírgula para não colidir com o separador.
      expect(lines[1], contains('Ação; Fantasia'));
    });

    test('nota zero vira campo vazio em vez de 0.0', () {
      final csv = ExportService.buildCsv([_item(rating: 0, genres: null)]);
      final fields = const LineSplitter().convert(csv)[1].split(',');
      expect(fields[7], isEmpty); // coluna "nota"
      expect(fields[10], isEmpty); // coluna "generos", nula no modelo
    });

    test('fonte e id externo fecham a linha, vazios quando não há vínculo', () {
      final lines = const LineSplitter().convert(
        ExportService.buildCsv([
          _item(externalId: 'mal-2', source: 'jikan'),
          _item(name: 'Anotado à mão'),
        ]),
      );

      final headers = lines.first.split(',');
      expect(headers.last, 'id_externo');
      expect(headers[headers.length - 2], 'fonte');

      final vindoDaBusca = lines[1].split(',');
      expect(vindoDaBusca.last, 'mal-2');
      expect(vindoDaBusca[vindoDaBusca.length - 2], 'jikan');

      // Item digitado à mão: as duas últimas colunas ficam vazias.
      expect(lines[2].endsWith(',,'), isTrue);
    });

    test('cabeçalho sozinho quando não há itens', () {
      final lines = const LineSplitter().convert(
        ExportService.buildCsv(const []),
      );
      expect(lines, hasLength(1));
    });
  });

  test('fileName usa a data corrente e a extensão pedida', () {
    final name = ExportService.fileName('json');
    expect(name, matches(RegExp(r'^onde-parei-\d{4}-\d{2}-\d{2}\.json$')));
  });

  group('review', () {
    test('sai no JSON junto com a nota', () {
      final decoded =
          jsonDecode(
                ExportService.buildJson(
                  userId: 'user-1',
                  items: [_item(review: 'Vale cada capítulo.')],
                ),
              )
              as Map<String, dynamic>;

      expect(decoded['formatVersion'], 3);
      expect((decoded['items'] as List).first['review'], 'Vale cada capítulo.');
    });

    test('ganha coluna própria no CSV, logo depois da nota', () {
      final lines = ExportService.buildCsv([
        _item(review: 'Curti muito'),
      ]).trim().split('\n');
      final headers = lines.first.split(',');

      expect(headers[8], 'review');
      expect(lines.last.split(',')[8], 'Curti muito');
    });

    test('review com vírgula não quebra as colunas', () {
      final lines = ExportService.buildCsv([
        _item(review: 'Bom, mas arrasta'),
      ]).trim().split('\n');

      expect(lines.last, contains('"Bom, mas arrasta"'));
    });
  });
}
