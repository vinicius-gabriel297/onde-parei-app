import 'package:cloud_firestore/cloud_firestore.dart';

/// Os índices são persistidos no Firestore — só adicione novos valores no FIM.
enum ItemType { manga, book, manhwa, manhua }

enum ReadingStatus { read, reading, wantToRead }

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
    }
  }
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
  final String? description;
  final String? author;
  final String? publishedDate;
  final List<String>? genres;
  final DateTime createdAt;
  final DateTime updatedAt;

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
    this.description,
    this.author,
    this.publishedDate,
    this.genres,
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
      description: data['description']?.toString(),
      author: data['author']?.toString(),
      publishedDate: data['publishedDate']?.toString(),
      genres: (data['genres'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList(),
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
      'description': description,
      'author': author,
      'publishedDate': publishedDate,
      'genres': genres,
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
    String? description,
    String? author,
    String? publishedDate,
    List<String>? genres,
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
      description: description ?? this.description,
      author: author ?? this.author,
      publishedDate: publishedDate ?? this.publishedDate,
      genres: genres ?? this.genres,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

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
}
