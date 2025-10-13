import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../models/item_model.dart';
import 'edit_item_screen.dart';

class ItemListScreen extends StatefulWidget {
  const ItemListScreen({super.key});

  @override
  State<ItemListScreen> createState() => _ItemListScreenState();
}

class _ItemListScreenState extends State<ItemListScreen> {
  ReadingStatus? _selectedStatusFilter;
  ItemType? _selectedTypeFilter;

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final firestoreService = Provider.of<FirestoreService>(context);

    final user = authService.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(
          child: Text('Usuário não autenticado'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF8D6E63), // Antique Brown - mesma cor dos outros headers
        foregroundColor: Colors.white, // Texto branco para contraste
        title: const Text(
          'Meus Itens',
          style: TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          // Filtros com melhor espaçamento
          Container(
            margin: const EdgeInsets.only(right: 8),
            child: PopupMenuButton<String>(
              onSelected: (value) {
                setState(() {
                  if (value == 'all') {
                    _selectedStatusFilter = null;
                    _selectedTypeFilter = null;
                  } else if (value.startsWith('status_')) {
                    final statusIndex = int.parse(value.split('_')[1]);
                    _selectedStatusFilter = ReadingStatus.values[statusIndex];
                    _selectedTypeFilter = null;
                  } else if (value.startsWith('type_')) {
                    final typeIndex = int.parse(value.split('_')[1]);
                    _selectedTypeFilter = ItemType.values[typeIndex];
                    _selectedStatusFilter = null;
                  }
                });
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'all',
                  child: Text('Todos'),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'status_0',
                  child: Text('Lidos'),
                ),
                const PopupMenuItem(
                  value: 'status_1',
                  child: Text('Lendo'),
                ),
                const PopupMenuItem(
                  value: 'status_2',
                  child: Text('Pretendo ler'),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'type_0',
                  child: Text('Mangás'),
                ),
                const PopupMenuItem(
                  value: 'type_1',
                  child: Text('Livros'),
                ),
              ],
              child: Container(
                padding: const EdgeInsets.all(8),
                child: const Icon(Icons.filter_list),
              ),
            ),
          ),
        ],
      ),
      body: StreamBuilder<List<ItemModel>>(
        stream: _getFilteredStream(firestoreService, user.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Erro ao carregar itens: ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
              ),
            );
          }

          final items = snapshot.data ?? [];

          if (items.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.library_books,
                    size: 80,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Nenhum item encontrado',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Adicione seu primeiro mangá ou livro',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return _ItemCard(
                item: item,
                onTap: () {
                  // TODO: Navegar para tela de detalhes
                },
                onEdit: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EditItemScreen(item: item),
                    ),
                  );
                },
                onDelete: () {
                  _showDeleteDialog(context, firestoreService, item);
                },
              );
            },
          );
        },
      ),
      // Removed floating action button since we have the "Meus Itens" view
    );
  }

  Stream<List<ItemModel>> _getFilteredStream(FirestoreService firestoreService, String userId) {
    if (_selectedStatusFilter != null) {
      return firestoreService.getUserItemsByStatus(userId, _selectedStatusFilter!);
    } else if (_selectedTypeFilter != null) {
      return firestoreService.getUserItemsByType(userId, _selectedTypeFilter!);
    } else {
      return firestoreService.getUserItems(userId);
    }
  }

  void _showDeleteDialog(BuildContext context, FirestoreService firestoreService, ItemModel item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir Item'),
        content: Text('Tem certeza que deseja excluir "${item.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              try {
                await firestoreService.deleteItem(item.id);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Item excluído com sucesso!'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Erro ao excluir item: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
  }
}

class _ItemCard extends StatelessWidget {
  final ItemModel item;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ItemCard({
    required this.item,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Imagem
              Container(
                width: 60,
                height: 80,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey.shade200,
                ),
                child: item.imageUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          item.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: Colors.grey.shade200,
                              child: Icon(
                                item.type == ItemType.manga ? Icons.book : Icons.menu_book,
                                color: Colors.grey,
                              ),
                            );
                          },
                        ),
                      )
                    : Icon(
                        item.type == ItemType.manga ? Icons.book : Icons.menu_book,
                        color: Colors.grey,
                        size: 30,
                      ),
              ),
              const SizedBox(width: 12),

              // Informações
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Título
                    Text(
                      item.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),

                    // Tipo
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: item.type == ItemType.manga
                            ? Colors.blue.shade100
                            : Colors.green.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        item.displayType,
                        style: TextStyle(
                          fontSize: 12,
                          color: item.type == ItemType.manga
                              ? Colors.blue.shade700
                              : Colors.green.shade700,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),

                    // Autor (se disponível)
                    if (item.author != null && item.author!.isNotEmpty)
                      Text(
                        item.author!,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),

                    // Posição atual
                    if (item.displayCurrentPosition.isNotEmpty)
                      Text(
                        item.displayCurrentPosition,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                      ),

                    // Avaliação
                    if (item.rating > 0)
                      Row(
                        children: [
                          const Icon(Icons.star, size: 16, color: Colors.amber),
                          Text(
                            ' ${item.rating.toStringAsFixed(1)}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                  ],
                ),
              ),

              // Status e ações
              Column(
                children: [
                  // Status
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(item.status).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _getStatusColor(item.status)),
                    ),
                    child: Text(
                      item.displayStatus,
                      style: TextStyle(
                        color: _getStatusColor(item.status),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Menu de ações
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'edit') {
                        onEdit();
                      } else if (value == 'delete') {
                        onDelete();
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit),
                            SizedBox(width: 8),
                            Text('Editar'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Excluir'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(ReadingStatus status) {
    switch (status) {
      case ReadingStatus.read:
        return Colors.green;
      case ReadingStatus.reading:
        return Colors.orange;
      case ReadingStatus.wantToRead:
        return Colors.blue;
    }
  }
}
