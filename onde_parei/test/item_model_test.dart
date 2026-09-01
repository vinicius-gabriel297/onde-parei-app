import 'package:flutter_test/flutter_test.dart';
import 'package:onde_parei/models/api_models.dart';
import 'package:onde_parei/models/item_model.dart';

ItemModel _item({String? externalId, String? source}) {
  final now = DateTime.utc(2026, 8, 31, 12);
  return ItemModel(
    id: 'abc123',
    userId: 'user-1',
    name: 'Berserk',
    type: ItemType.manga,
    status: ReadingStatus.reading,
    currentChapter: '364',
    currentPage: '',
    rating: 5,
    externalId: externalId,
    source: source,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('vínculo com a origem', () {
    test('vai e volta pelo mapa do Firestore', () {
      final data = _item(externalId: 'mal-2', source: 'jikan').toFirestore();

      expect(data['externalId'], 'mal-2');
      expect(data['source'], 'jikan');
    });

    test('item digitado à mão grava os dois campos nulos', () {
      final data = _item().toFirestore();

      expect(data['externalId'], isNull);
      expect(data['source'], isNull);
    });

    test('copyWith preserva o vínculo ao editar outros campos', () {
      final editado = _item(
        externalId: 'mal-2',
        source: 'jikan',
      ).copyWith(currentChapter: '365');

      expect(editado.currentChapter, '365');
      expect(editado.sourceKey, 'jikan:mal-2');
    });

    test('sourceKey exige as duas metades', () {
      expect(
        _item(externalId: 'mal-2', source: 'jikan').sourceKey,
        'jikan:mal-2',
      );
      expect(_item(externalId: 'mal-2').sourceKey, isNull);
      expect(_item(source: 'jikan').sourceKey, isNull);
      expect(_item().sourceKey, isNull);
    });
  });

  group('fonte de um resultado de busca', () {
    SearchResult result({
      SearchSource source = SearchSource.catalog,
      SearchSource? originSource,
    }) => SearchResult(
      id: 'mal-2',
      title: 'Berserk',
      type: 'manga',
      source: source,
      originSource: originSource,
    );

    test('o catálogo repassa a fonte que produziu os dados', () {
      expect(
        result(originSource: SearchSource.jikan).effectiveSource,
        SearchSource.jikan,
      );
    });

    test('sem origem registrada, sobra o próprio catálogo', () {
      expect(result().effectiveSource, SearchSource.catalog);
    });

    test('resultado direto de uma API é a própria fonte', () {
      expect(
        result(source: SearchSource.googleBooks).effectiveSource,
        SearchSource.googleBooks,
      );
    });

    test('nome persistido volta a virar enum, e o desconhecido vira nulo', () {
      expect(searchSourceFromName('jikan'), SearchSource.jikan);
      expect(searchSourceFromName('googleBooks'), SearchSource.googleBooks);
      expect(searchSourceFromName('fonte-que-nao-existe-mais'), isNull);
      expect(searchSourceFromName(null), isNull);
      expect(searchSourceFromName(''), isNull);
    });
  });
}
