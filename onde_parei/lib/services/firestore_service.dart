import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/item_model.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Coleção de itens
  CollectionReference get _itemsCollection => _db.collection('items');

  // Adicionar novo item
  Future<String> addItem(ItemModel item) async {
    try {
      final docRef = await _itemsCollection.add(item.toFirestore());
      return docRef.id;
    } catch (e) {
      if (e.toString().contains('permission-denied')) {
        throw Exception(
          'Erro de permissão: Configure as regras de segurança do Firestore primeiro',
        );
      } else if (e.toString().contains('unavailable')) {
        throw Exception(
          'Erro de conexão: Verifique sua conexão com a internet',
        );
      } else {
        throw Exception('Erro ao adicionar item: $e');
      }
    }
  }

  // Atualizar item existente
  Future<void> updateItem(ItemModel item) async {
    try {
      await _itemsCollection.doc(item.id).update(item.toFirestore());
    } catch (e) {
      if (e.toString().contains('permission-denied')) {
        throw Exception(
          'Erro de permissão: Configure as regras de segurança do Firestore primeiro',
        );
      } else if (e.toString().contains('unavailable')) {
        throw Exception(
          'Erro de conexão: Verifique sua conexão com a internet',
        );
      } else {
        throw Exception('Erro ao atualizar item: $e');
      }
    }
  }

  // Remover item
  Future<void> deleteItem(String itemId) async {
    try {
      await _itemsCollection.doc(itemId).delete();
    } catch (e) {
      if (e.toString().contains('permission-denied')) {
        throw Exception(
          'Erro de permissão: Configure as regras de segurança do Firestore primeiro',
        );
      } else if (e.toString().contains('unavailable')) {
        throw Exception(
          'Erro de conexão: Verifique sua conexão com a internet',
        );
      } else {
        throw Exception('Erro ao remover item: $e');
      }
    }
  }

  // Buscar itens do usuário
  Stream<List<ItemModel>> getUserItems(String userId) {
    return _itemsCollection
        .where('userId', isEqualTo: userId)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => ItemModel.fromFirestore(doc))
              .toList();
        });
  }

  // Buscar item específico
  Future<ItemModel?> getItem(String itemId) async {
    try {
      final doc = await _itemsCollection.doc(itemId).get();
      if (doc.exists) {
        return ItemModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      throw Exception('Erro ao buscar item: $e');
    }
  }

  // Buscar itens por status
  Stream<List<ItemModel>> getUserItemsByStatus(
    String userId,
    ReadingStatus status,
  ) {
    return _itemsCollection
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: status.index)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => ItemModel.fromFirestore(doc))
              .toList();
        });
  }

  // Buscar itens por tipo
  Stream<List<ItemModel>> getUserItemsByType(String userId, ItemType type) {
    return _itemsCollection
        .where('userId', isEqualTo: userId)
        .where('type', isEqualTo: type.index)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => ItemModel.fromFirestore(doc))
              .toList();
        });
  }

  // Buscar estatísticas do usuário
  Future<Map<String, dynamic>> getUserStats(String userId) async {
    try {
      final snapshot = await _itemsCollection
          .where('userId', isEqualTo: userId)
          .get();

      int totalMangas = 0;
      int totalBooks = 0;
      int readCount = 0;
      int readingCount = 0;
      int wantToReadCount = 0;
      double totalRating = 0;
      int ratedCount = 0;

      for (final doc in snapshot.docs) {
        final item = ItemModel.fromFirestore(doc);

        if (item.type == ItemType.manga) {
          totalMangas++;
        } else {
          totalBooks++;
        }

        switch (item.status) {
          case ReadingStatus.read:
            readCount++;
            break;
          case ReadingStatus.reading:
            readingCount++;
            break;
          case ReadingStatus.wantToRead:
            wantToReadCount++;
            break;
        }

        if (item.rating > 0) {
          totalRating += item.rating;
          ratedCount++;
        }
      }

      return {
        'totalItems': snapshot.docs.length,
        'totalMangas': totalMangas,
        'totalBooks': totalBooks,
        'readCount': readCount,
        'readingCount': readingCount,
        'wantToReadCount': wantToReadCount,
        'averageRating': ratedCount > 0 ? totalRating / ratedCount : 0.0,
        'ratedCount': ratedCount,
      };
    } catch (e) {
      // Melhorar tratamento de erros para problemas de permissão
      if (e.toString().contains('permission-denied')) {
        throw Exception(
          'Erro de permissão: As regras de segurança do Firestore precisam ser configuradas. Execute o arquivo deploy_firestore_rules.bat',
        );
      } else if (e.toString().contains('unavailable')) {
        throw Exception(
          'Erro de conexão: Verifique sua conexão com a internet',
        );
      } else {
        throw Exception('Erro ao buscar estatísticas: $e');
      }
    }
  }

  // Migração: normaliza URLs de capa com http:// para https:// (evita mixed content no Web)
  Future<int> migrateUserImageUrlsToHttps(String userId) async {
    try {
      final snapshot = await _itemsCollection
          .where('userId', isEqualTo: userId)
          .get();

      final batch = _db.batch();
      int updatedCount = 0;

      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final imageUrl = data['imageUrl'];

        if (imageUrl is String && imageUrl.startsWith('http://')) {
          batch.update(doc.reference, {
            'imageUrl': imageUrl.replaceFirst('http://', 'https://'),
            'updatedAt': Timestamp.fromDate(DateTime.now()),
          });
          updatedCount++;
        }
      }

      if (updatedCount > 0) {
        await batch.commit();
      }

      return updatedCount;
    } catch (e) {
      throw Exception('Erro ao migrar URLs de imagem para HTTPS: $e');
    }
  }
}
