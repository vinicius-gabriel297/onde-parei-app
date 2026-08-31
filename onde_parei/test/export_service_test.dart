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
  String? author = 'Kentaro Miura',
  List<String>? genres = const ['Ação', 'Fantasia'],
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
    author: author,
    genres: genres,
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
}
