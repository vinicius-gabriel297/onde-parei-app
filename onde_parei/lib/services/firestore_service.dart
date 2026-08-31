import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/api_models.dart';
import '../models/item_model.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference get _itemsCollection => _db.collection('items');

  /// Catálogo compartilhado — guarda títulos já pesquisados por qualquer
  /// usuário para que a próxima busca pelo mesmo termo seja instantânea.
  CollectionReference get _catalogCollection => _db.collection('book_catalog');

  String _friendlyError(Object e, String action) {
    final text = e.toString();
    if (text.contains('permission-denied')) {
      return 'Sem permissão para $action. Verifique as regras do Firestore.';
    }
    if (text.contains('unavailable')) {
      return 'Sem conexão. Verifique sua internet e tente de novo.';
    }
    return 'Não foi possível $action: $e';
  }

  // ─── CRUD ─────────────────────────────────────────────────────────────────

  Future<String> addItem(ItemModel item) async {
    try {
      final docRef = await _itemsCollection.add(item.toFirestore());
      return docRef.id;
    } catch (e) {
      throw Exception(_friendlyError(e, 'adicionar o item'));
    }
  }

  Future<void> updateItem(ItemModel item) async {
    try {
      await _itemsCollection.doc(item.id).update(item.toFirestore());
    } catch (e) {
      throw Exception(_friendlyError(e, 'atualizar o item'));
    }
  }

  /// Atualização parcial usada pelos atalhos de progresso (+1 capítulo etc.),
  /// evitando reescrever o documento inteiro.
  Future<void> updateFields(String itemId, Map<String, dynamic> fields) async {
    try {
      await _itemsCollection.doc(itemId).update({
        ...fields,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      throw Exception(_friendlyError(e, 'atualizar o item'));
    }
  }

  Future<void> deleteItem(String itemId) async {
    try {
      await _itemsCollection.doc(itemId).delete();
    } catch (e) {
      throw Exception(_friendlyError(e, 'remover o item'));
    }
  }

  // ─── Consultas ────────────────────────────────────────────────────────────

  Stream<List<ItemModel>> getUserItems(String userId) {
    return _itemsCollection
        .where('userId', isEqualTo: userId)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => ItemModel.fromFirestore(doc)).toList(),
        );
  }

  Future<ItemModel?> getItem(String itemId) async {
    try {
      final doc = await _itemsCollection.doc(itemId).get();
      return doc.exists ? ItemModel.fromFirestore(doc) : null;
    } catch (e) {
      throw Exception(_friendlyError(e, 'buscar o item'));
    }
  }

  Stream<List<ItemModel>> getUserItemsByStatus(
    String userId,
    ReadingStatus status,
  ) {
    return _itemsCollection
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: status.index)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => ItemModel.fromFirestore(doc)).toList(),
        );
  }

  Stream<List<ItemModel>> getUserItemsByType(String userId, ItemType type) {
    return _itemsCollection
        .where('userId', isEqualTo: userId)
        .where('type', isEqualTo: type.index)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => ItemModel.fromFirestore(doc)).toList(),
        );
  }

  /// Estatísticas derivadas de uma lista já carregada — evita uma segunda
  /// leitura completa da coleção só para contar itens.
  static Map<String, dynamic> statsFrom(List<ItemModel> items) {
    var totalMangas = 0;
    var totalBooks = 0;
    var readCount = 0;
    var readingCount = 0;
    var wantToReadCount = 0;
    var totalRating = 0.0;
    var ratedCount = 0;

    for (final item in items) {
      if (item.type.isBook) {
        totalBooks++;
      } else {
        totalMangas++;
      }

      switch (item.status) {
        case ReadingStatus.read:
          readCount++;
        case ReadingStatus.reading:
          readingCount++;
        case ReadingStatus.wantToRead:
          wantToReadCount++;
      }

      if (item.rating > 0) {
        totalRating += item.rating;
        ratedCount++;
      }
    }

    return {
      'totalItems': items.length,
      'totalMangas': totalMangas,
      'totalBooks': totalBooks,
      'readCount': readCount,
      'readingCount': readingCount,
      'wantToReadCount': wantToReadCount,
      'averageRating': ratedCount > 0 ? totalRating / ratedCount : 0.0,
      'ratedCount': ratedCount,
    };
  }

  Future<Map<String, dynamic>> getUserStats(String userId) async {
    try {
      final snapshot = await _itemsCollection
          .where('userId', isEqualTo: userId)
          .get();
      return statsFrom(
        snapshot.docs.map((doc) => ItemModel.fromFirestore(doc)).toList(),
      );
    } catch (e) {
      throw Exception(_friendlyError(e, 'carregar as estatísticas'));
    }
  }

  // ─── Catálogo compartilhado ───────────────────────────────────────────────

  /// Guarda o título no catálogo. Silencioso de propósito: nunca deve impedir
  /// o usuário de salvar o próprio item.
  Future<void> upsertBookToCatalog(SearchResult result, String userId) async {
    try {
      final data = <String, dynamic>{
        'externalId': result.id,
        'title': result.title,
        'titleLower': result.title.toLowerCase(),
        'type': result.type,
        'imageUrl': result.imageUrl,
        'description': result.description,
        'authors': result.authors ?? const [],
        'year': result.year,
        'totalUnits': result.totalUnits,
        'genres': result.genres ?? const [],
        'popularity': result.popularity,
        'addedBy': userId,
        'addedAt': FieldValue.serverTimestamp(),
      };

      await _catalogCollection
          .doc(result.id)
          .set(data, SetOptions(merge: true));
    } catch (_) {
      // Cache best-effort.
    }
  }

  /// Busca por prefixo de título no catálogo. Responde em poucas centenas de
  /// milissegundos e é a primeira fonte a aparecer na tela.
  ///
  /// O `\uf8ff` no limite superior é o truque padrão de prefixo do Firestore:
  /// é quase o último code point da área de uso privado, então a faixa cobre
  /// todo título que comece por `q`. Escrito como escape de propósito — como
  /// caractere literal ele fica invisível no editor e some em um copiar/colar.
  Future<List<SearchResult>> searchBookCatalog(
    String query, {
    int limit = 10,
  }) async {
    final q = query.toLowerCase().trim();
    if (q.isEmpty) return const [];

    try {
      final snapshot = await _catalogCollection
          .where('titleLower', isGreaterThanOrEqualTo: q)
          .where('titleLower', isLessThanOrEqualTo: '$q\uf8ff')
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) {
            final d = doc.data() as Map<String, dynamic>;
            return SearchResult(
              id: d['externalId']?.toString() ?? doc.id,
              title: d['title']?.toString() ?? '',
              imageUrl: d['imageUrl']?.toString(),
              description: d['description']?.toString(),
              authors: (d['authors'] as List<dynamic>?)
                  ?.map((e) => e.toString())
                  .toList(),
              type: d['type']?.toString() ?? 'book',
              source: SearchSource.catalog,
              year: d['year']?.toString(),
              totalUnits: (d['totalUnits'] as num?)?.toInt(),
              genres: (d['genres'] as List<dynamic>?)
                  ?.map((e) => e.toString())
                  .toList(),
              popularity: (d['popularity'] as num?)?.toInt() ?? 0,
              rawData: {
                'publishedDate': d['year'],
                'pageCount': d['totalUnits'],
                'chapters': d['totalUnits'],
                'genres': d['genres'],
              },
            );
          })
          .where((r) => r.title.isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  // ─── Conta e dados ────────────────────────────────────────────────────────

  /// Lê a estante inteira uma única vez. Usado pela exportação, que precisa de
  /// um retrato do momento e não de um stream.
  Future<List<ItemModel>> fetchUserItemsOnce(String userId) async {
    try {
      final snapshot = await _itemsCollection
          .where('userId', isEqualTo: userId)
          .orderBy('updatedAt', descending: true)
          .get();
      return snapshot.docs.map((doc) => ItemModel.fromFirestore(doc)).toList();
    } catch (e) {
      throw Exception(_friendlyError(e, 'carregar seus dados'));
    }
  }

  /// Apaga todos os documentos do usuário. Precisa rodar ANTES de excluir a
  /// conta no Auth: as regras exigem `request.auth.uid`, então um usuário já
  /// removido não consegue mais apagar os próprios itens e eles ficariam órfãos.
  ///
  /// Retorna quantos documentos foram removidos.
  Future<int> deleteAllUserData(String userId) async {
    try {
      final snapshot = await _itemsCollection
          .where('userId', isEqualTo: userId)
          .get();

      var deleted = 0;
      // O Firestore limita cada batch a 500 operações.
      for (var start = 0; start < snapshot.docs.length; start += 500) {
        final end = (start + 500 < snapshot.docs.length)
            ? start + 500
            : snapshot.docs.length;
        final batch = _db.batch();
        for (final doc in snapshot.docs.sublist(start, end)) {
          batch.delete(doc.reference);
        }
        await batch.commit();
        deleted += end - start;
      }

      return deleted;
    } catch (e) {
      throw Exception(_friendlyError(e, 'apagar seus dados'));
    }
  }

  // ─── Manutenção ───────────────────────────────────────────────────────────

  /// Normaliza capas http:// para https:// (mixed content no Web).
  Future<int> migrateUserImageUrlsToHttps(String userId) async {
    try {
      final snapshot = await _itemsCollection
          .where('userId', isEqualTo: userId)
          .get();

      final batch = _db.batch();
      var updatedCount = 0;

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

      if (updatedCount > 0) await batch.commit();
      return updatedCount;
    } catch (e) {
      throw Exception(_friendlyError(e, 'migrar as capas para HTTPS'));
    }
  }
}
