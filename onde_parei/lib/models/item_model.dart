import 'package:cloud_firestore/cloud_firestore.dart';

enum ItemType { manga, book }

enum ReadingStatus { read, reading, wantToRead }

class ItemModel {
  final String id;
  final String userId;
  final String name;
  final String? imageUrl;
  final ItemType type;
  final ReadingStatus status;
  final String currentChapter; // Para mangás
  final String currentPage; // Para livros
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
    required this.rating,
    this.description,
    this.author,
    this.publishedDate,
    this.genres,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ItemModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    return ItemModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      name: data['name'] ?? '',
      imageUrl: normalizeImageUrl(data['imageUrl'] as String?),
      type: ItemType.values[data['type'] ?? 0],
      status: ReadingStatus.values[data['status'] ?? 0],
      currentChapter: data['currentChapter'] ?? '',
      currentPage: data['currentPage'] ?? '',
      rating: (data['rating'] ?? 0).toDouble(),
      description: data['description'],
      author: data['author'],
      publishedDate: data['publishedDate'],
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
      'imageUrl': normalizeImageUrl(imageUrl),
      'type': type.index,
      'status': status.index,
      'currentChapter': currentChapter,
      'currentPage': currentPage,
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
      rating: rating ?? this.rating,
      description: description ?? this.description,
      author: author ?? this.author,
      publishedDate: publishedDate ?? this.publishedDate,
      genres: genres ?? this.genres,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  String get displayCurrentPosition {
    if (type == ItemType.manga) {
      return currentChapter.isNotEmpty ? 'Capítulo $currentChapter' : '';
    } else {
      return currentPage.isNotEmpty ? 'Página $currentPage' : '';
    }
  }

  String get displayStatus {
    switch (status) {
      case ReadingStatus.read:
        return 'Lido';
      case ReadingStatus.reading:
        return 'Lendo';
      case ReadingStatus.wantToRead:
        return 'Pretendo ler';
    }
  }

  String get displayType {
    switch (type) {
      case ItemType.manga:
        return 'Mangá';
      case ItemType.book:
        return 'Livro';
    }
  }
}
