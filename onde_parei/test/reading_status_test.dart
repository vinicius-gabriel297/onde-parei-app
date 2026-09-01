import 'package:flutter_test/flutter_test.dart';
import 'package:onde_parei/models/item_model.dart';
import 'package:onde_parei/services/firestore_service.dart';

ItemModel _item(ReadingStatus status, {double rating = 0}) {
  final now = DateTime.utc(2026, 8, 31, 12);
  return ItemModel(
    id: 'id-${status.name}',
    userId: 'user-1',
    name: 'Título',
    type: ItemType.manga,
    status: status,
    currentChapter: '10',
    currentPage: '',
    rating: rating,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('ReadingStatus', () {
    test('os índices persistidos não mudaram', () {
      // O Firestore guarda o índice do enum. Trocar a ordem reescreveria o
      // status de todos os itens já salvos — este teste é o alarme.
      expect(ReadingStatus.read.index, 0);
      expect(ReadingStatus.reading.index, 1);
      expect(ReadingStatus.wantToRead.index, 2);
      expect(ReadingStatus.paused.index, 3);
      expect(ReadingStatus.dropped.index, 4);
    });

    test('todo status tem rótulo próprio', () {
      final labels = ReadingStatus.values.map((s) => s.label).toList();

      expect(labels.toSet(), hasLength(ReadingStatus.values.length));
      expect(ReadingStatus.paused.label, 'Em pausa');
      expect(ReadingStatus.dropped.label, 'Abandonei');
    });

    test('displayOrder mostra todos os status, sem repetir', () {
      // Se alguém acrescentar um status e esquecer da ordem de exibição, ele
      // sumiria do seletor e dos filtros sem quebrar nada. Aqui quebra.
      expect(ReadingStatusX.displayOrder.toSet(), ReadingStatus.values.toSet());
      expect(
        ReadingStatusX.displayOrder,
        hasLength(ReadingStatus.values.length),
      );
    });

    test('só as leituras que ainda podem andar são "em curso"', () {
      expect(ReadingStatus.reading.isOngoing, isTrue);
      expect(ReadingStatus.wantToRead.isOngoing, isTrue);
      expect(ReadingStatus.paused.isOngoing, isTrue);
      expect(ReadingStatus.read.isOngoing, isFalse);
      expect(ReadingStatus.dropped.isOngoing, isFalse);
    });
  });

  group('statsFrom', () {
    test('conta cada status em sua própria caixa', () {
      final stats = FirestoreService.statsFrom([
        _item(ReadingStatus.reading),
        _item(ReadingStatus.reading),
        _item(ReadingStatus.read, rating: 4),
        _item(ReadingStatus.wantToRead),
        _item(ReadingStatus.paused),
        _item(ReadingStatus.dropped),
      ]);

      expect(stats['totalItems'], 6);
      expect(stats['readingCount'], 2);
      expect(stats['readCount'], 1);
      expect(stats['wantToReadCount'], 1);
      expect(stats['pausedCount'], 1);
      expect(stats['droppedCount'], 1);
      // Só o item com nota entra na média.
      expect(stats['averageRating'], 4.0);
      expect(stats['ratedCount'], 1);
    });

    test('estante vazia não divide por zero', () {
      final stats = FirestoreService.statsFrom(const []);

      expect(stats['totalItems'], 0);
      expect(stats['pausedCount'], 0);
      expect(stats['droppedCount'], 0);
      expect(stats['averageRating'], 0.0);
    });
  });
}
