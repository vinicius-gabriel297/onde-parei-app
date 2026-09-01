import 'dart:convert';

import '../models/item_model.dart';

/// Monta os arquivos de exportação da estante. Só transforma dados em texto —
/// quem entrega o arquivo ao usuário é `file_download.dart`.
abstract final class ExportService {
  /// 2 acrescentou `source` e `externalId` em cada item. Quem lê uma exportação
  /// da versão 1 só não encontra esses dois campos; o resto é igual.
  static const jsonFormatVersion = 2;

  /// Retrato completo da conta em JSON. É o formato canônico: preserva tipos,
  /// datas em ISO 8601 e campos vazios, então serve para reimportar depois.
  static String buildJson({
    required String userId,
    String? email,
    String? displayName,
    required List<ItemModel> items,
  }) {
    final payload = <String, dynamic>{
      'app': 'Onde Parei?',
      'formatVersion': jsonFormatVersion,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'account': {
        'userId': userId,
        'email': email,
        'displayName': displayName,
      },
      'itemCount': items.length,
      'items': [
        for (final item in items)
          {
            'id': item.id,
            'name': item.name,
            'type': item.type.name,
            'status': item.status.name,
            'currentChapter': item.currentChapter,
            'totalChapters': item.totalChapters,
            'currentPage': item.currentPage,
            'totalPages': item.totalPages,
            'rating': item.rating,
            'author': item.author,
            'publishedDate': item.publishedDate,
            'genres': item.genres ?? const <String>[],
            'description': item.description,
            'imageUrl': item.imageUrl,
            // Nome cru da fonte, não o rótulo de tela: é o que permite casar
            // o item de volta com a origem em uma reimportação.
            'source': item.source,
            'externalId': item.externalId,
            'createdAt': item.createdAt.toUtc().toIso8601String(),
            'updatedAt': item.updatedAt.toUtc().toIso8601String(),
          },
      ],
    };

    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  /// Mesma estante em CSV, para quem quer abrir em planilha. Perde o aninhamento
  /// (gêneros viram texto separado por `;`), então não substitui o JSON.
  static String buildCsv(List<ItemModel> items) {
    const headers = [
      'nome',
      'tipo',
      'status',
      'capitulo_atual',
      'total_capitulos',
      'pagina_atual',
      'total_paginas',
      'nota',
      'autor',
      'ano',
      'generos',
      'criado_em',
      'atualizado_em',
      'fonte',
      'id_externo',
    ];

    final buffer = StringBuffer()..writeln(headers.join(','));

    for (final item in items) {
      buffer.writeln(
        [
          item.name,
          item.type.label,
          item.status.label,
          item.currentChapter,
          item.totalChapters,
          item.currentPage,
          item.totalPages,
          item.rating == 0 ? '' : item.rating.toString(),
          item.author ?? '',
          item.publishedDate ?? '',
          (item.genres ?? const <String>[]).join('; '),
          item.createdAt.toUtc().toIso8601String(),
          item.updatedAt.toUtc().toIso8601String(),
          item.source ?? '',
          item.externalId ?? '',
        ].map(_csvField).join(','),
      );
    }

    // BOM: sem ele o Excel abre os acentos errados.
    return '﻿$buffer';
  }

  /// Aspas duplas viram duas aspas; só delimita quando o campo tem separador,
  /// aspas ou quebra de linha.
  static String _csvField(String value) {
    if (!value.contains(RegExp(r'[",\n\r]'))) return value;
    return '"${value.replaceAll('"', '""')}"';
  }

  /// Nome de arquivo com a data, para não sobrescrever exportações anteriores.
  static String fileName(String extension) {
    final now = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return 'onde-parei-${now.year}-${two(now.month)}-${two(now.day)}.$extension';
  }
}
