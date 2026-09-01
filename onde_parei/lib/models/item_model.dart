import 'package:cloud_firestore/cloud_firestore.dart';

/// Os índices são persistidos no Firestore — só adicione novos valores no FIM.
enum ItemType { manga, book, manhwa, manhua }

/// `paused` e `dropped` entraram depois — por isso estão no fim, e é por isso
/// que a ordem de exibição na UI vive em `ReadingStatusX.displayOrder`, e não
/// aqui.
enum ReadingStatus { read, reading, wantToRead, paused, dropped }

extension ItemTypeX on ItemType {
  bool get isBook => this == ItemType.book;

  /// Mangá, manhwa e manhua contam capítulos; livro conta páginas.
  bool get countsChapters => this != ItemType.book;

  String get label {
    switch (this) {
      case ItemType.manga:
        return 'Mangá';
      case ItemType.book:
        return 'Livro';
      case ItemType.manhwa:
        return 'Manhwa';
      case ItemType.manhua:
        return 'Manhua';
    }
  }

  static ItemType fromSearchType(String type) {
    switch (type) {
      case 'manga':
        return ItemType.manga;
      case 'manhwa':
        return ItemType.manhwa;
      case 'manhua':
        return ItemType.manhua;
      default:
        return ItemType.book;
    }
  }
}

extension ReadingStatusX on ReadingStatus {
  String get label {
    switch (this) {
      case ReadingStatus.read:
        return 'Lido';
      case ReadingStatus.reading:
        return 'Lendo';
      case ReadingStatus.wantToRead:
        return 'Quero ler';
      case ReadingStatus.paused:
        return 'Em pausa';
      case ReadingStatus.dropped:
        return 'Abandonei';
    }
  }

  /// Uma leitura que ainda pode voltar a andar. Separa quem está no meio do
  /// caminho de quem já encerrou — por ter terminado ou por ter desistido.
  bool get isOngoing =>
      this == ReadingStatus.reading ||
      this == ReadingStatus.wantToRead ||
      this == ReadingStatus.paused;

  /// Ordem em que os status aparecem na tela, do mais ao menos frequente.
  /// Existe separada de `values` porque aquela é a ordem de persistência e
  /// não pode ser mexida.
  static const displayOrder = <ReadingStatus>[
    ReadingStatus.reading,
    ReadingStatus.wantToRead,
    ReadingStatus.paused,
    ReadingStatus.read,
    ReadingStatus.dropped,
  ];
}

class ItemModel {
  final String id;
  final String userId;
  final String name;
  final String? imageUrl;
  final ItemType type;
  final ReadingStatus status;
  final String currentChapter;
  final String currentPage;

  /// Totais opcionais — habilitam a barra de progresso.
  final String totalChapters;
  final String totalPages;

  final double rating;

  /// Review final da obra, escrito quando a leitura encerra. Vazio = sem
  /// review. Segue `currentChapter` e `totalPages`: String vazia em vez de
  /// null, para o campo poder ser limpo sem sentinela no `copyWith`.
  final String review;

  final String? description;
  final String? author;
  final String? publishedDate;
  final List<String>? genres;

  /// Vínculo com a obra na fonte de onde ela veio: o identificador de lá
  /// (`mal-1234`, `OL45804W`, …) e o nome da fonte (`jikan`, `googleBooks`, …).
  /// Só existem em item criado a partir de uma busca — item digitado à mão
  /// fica com os dois nulos.
  ///
  /// É o que permite reencontrar a obra na origem depois: conferir capítulos
  /// novos, reimportar dados ou casar a estante com outro serviço, sem depender
  /// do título, que muda de grafia entre fontes.
  final String? externalId;
  final String? source;

  final DateTime createdAt;
  final DateTime updatedAt;

  /// Texto vindo do Firestore que pode estar ausente, nulo ou vazio — os três
  /// significam "não sei de onde veio".
  static String? _nonEmpty(dynamic value) {
    final text = value?.toString().trim();
    return (text == null || text.isEmpty) ? null : text;
  }

  static String? normalizeImageUrl(String? url) {
    if (url == null || url.trim().isEmpty) return url;
    return url.replaceFirst('http://', 'https://');
  }

  ItemModel({
    required this.id,
    required this.userId,
    required this.name,
    this.imageUrl,
    required this.type,
    required this.status,
    required this.currentChapter,
    required this.currentPage,
    this.totalChapters = '',
    this.totalPages = '',
    required this.rating,
    this.review = '',
    this.description,
    this.author,
    this.publishedDate,
    this.genres,
    this.externalId,
    this.source,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ItemModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final typeIndex = (data['type'] as num?)?.toInt() ?? 0;
    final statusIndex = (data['status'] as num?)?.toInt() ?? 0;

    return ItemModel(
      id: doc.id,
      userId: data['userId']?.toString() ?? '',
      name: data['name']?.toString() ?? '',
      imageUrl: normalizeImageUrl(data['imageUrl'] as String?),
      type: typeIndex >= 0 && typeIndex < ItemType.values.length
          ? ItemType.values[typeIndex]
          : ItemType.book,
      status: statusIndex >= 0 && statusIndex < ReadingStatus.values.length
          ? ReadingStatus.values[statusIndex]
          : ReadingStatus.wantToRead,
      currentChapter: data['currentChapter']?.toString() ?? '',
      currentPage: data['currentPage']?.toString() ?? '',
      totalChapters: data['totalChapters']?.toString() ?? '',
      totalPages: data['totalPages']?.toString() ?? '',
      rating: (data['rating'] as num?)?.toDouble() ?? 0,
      review: data['review']?.toString() ?? '',
      description: data['description']?.toString(),
      author: data['author']?.toString(),
      publishedDate: data['publishedDate']?.toString(),
      genres: (data['genres'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList(),
      externalId: _nonEmpty(data['externalId']),
      source: _nonEmpty(data['source']),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'name': name,
      'nameLower': name.toLowerCase(),
      'imageUrl': normalizeImageUrl(imageUrl),
      'type': type.index,
      'status': status.index,
      'currentChapter': currentChapter,
      'currentPage': currentPage,
      'totalChapters': totalChapters,
      'totalPages': totalPages,
      'rating': rating,
      'review': review,
      'description': description,
      'author': author,
      'publishedDate': publishedDate,
      'genres': genres,
      'externalId': externalId,
      'source': source,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  ItemModel copyWith({
    String? id,
    String? userId,
    String? name,
    String? imageUrl,
    ItemType? type,
    ReadingStatus? status,
    String? currentChapter,
    String? currentPage,
    String? totalChapters,
    String? totalPages,
    double? rating,
    String? review,
    String? description,
    String? author,
    String? publishedDate,
    List<String>? genres,
    String? externalId,
    String? source,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ItemModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      imageUrl: normalizeImageUrl(imageUrl ?? this.imageUrl),
      type: type ?? this.type,
      status: status ?? this.status,
      currentChapter: currentChapter ?? this.currentChapter,
      currentPage: currentPage ?? this.currentPage,
      totalChapters: totalChapters ?? this.totalChapters,
      totalPages: totalPages ?? this.totalPages,
      rating: rating ?? this.rating,
      review: review ?? this.review,
      description: description ?? this.description,
      author: author ?? this.author,
      publishedDate: publishedDate ?? this.publishedDate,
      genres: genres ?? this.genres,
      externalId: externalId ?? this.externalId,
      source: source ?? this.source,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Se há review escrito. Um texto só de espaços não conta.
  bool get hasReview => review.trim().isNotEmpty;

  /// Posição atual como número, quando informada.
  int? get currentValue =>
      int.tryParse((type.countsChapters ? currentChapter : currentPage).trim());

  int? get totalValue =>
      int.tryParse((type.countsChapters ? totalChapters : totalPages).trim());

  /// Fração lida (0..1) — só existe quando há atual e total válidos.
  double? get progress {
    if (status == ReadingStatus.read) return 1;
    final current = currentValue;
    final total = totalValue;
    if (current == null || total == null || total <= 0) return null;
    return (current / total).clamp(0.0, 1.0);
  }

  String get unitLabel => type.countsChapters ? 'Capítulo' : 'Página';

  String get displayCurrentPosition {
    final current = type.countsChapters ? currentChapter : currentPage;
    if (current.trim().isEmpty) return '';
    final total = type.countsChapters ? totalChapters : totalPages;
    if (total.trim().isNotEmpty) return '$unitLabel $current de $total';
    return '$unitLabel $current';
  }

  String get displayStatus => status.label;

  String get displayType => type.label;

  /// Identidade da obra na origem, igual para todo mundo que salvou o mesmo
  /// título pela mesma fonte. `null` em item criado à mão.
  String? get sourceKey =>
      (source != null && externalId != null) ? '$source:$externalId' : null;
}
