import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../services/settings_service.dart';
import '../../models/item_model.dart';
import '../items/item_list_screen.dart';
import '../items/add_item_screen.dart';
import '../search/search_screen.dart';
import '../settings/settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  Future<String> _getDisplayName(
    String userId,
    String fallbackEmail,
    SettingsService settingsService,
  ) async {
    try {
      final settings = await settingsService.loadSettings(userId);
      return settings.displayName.isNotEmpty
          ? settings.displayName
          : fallbackEmail.split('@')[0];
    } catch (e) {
      return fallbackEmail.split('@')[0];
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final firestoreService = Provider.of<FirestoreService>(context);
    final settingsService = Provider.of<SettingsService>(context);

    final user = authService.currentUser;
    final userEmail = user?.email ?? 'Usuário';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF8D6E63), // Antique Brown - mesma cor do FAB
        foregroundColor: Colors.white, // Texto branco para contraste
        title: Row(
          children: [
            const Icon(
              Icons.book, // Ícone de livro
              color: Colors.white,
            ),
            const SizedBox(width: 8),
            const Text('Onde Parei ?'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
            tooltip: 'Configurações',
          ),
        ],
      ),
      body: Column(
        children: [
          // Saudação do usuário com nome de exibição
          FutureBuilder<String>(
            future: _getDisplayName(user!.uid, userEmail, settingsService),
            builder: (context, snapshot) {
              final displayName = snapshot.data ?? userEmail.split('@')[0];

              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    const CircleAvatar(
                      backgroundColor: Colors.blue,
                      child: Icon(Icons.person, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Olá, $displayName!',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Text(
                            'Gerencie seus mangás e livros',
                            style: TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          // Estatísticas rápidas
          FutureBuilder<Map<String, dynamic>>(
            future: firestoreService.getUserStats(user!.uid),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const LinearProgressIndicator();
              }

              if (snapshot.hasError) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Erro ao carregar estatísticas: ${snapshot.error}',
                    style: const TextStyle(color: Colors.red),
                  ),
                );
              }

              final stats = snapshot.data ?? {};

              return Container(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        title: 'Total',
                        value: '${stats['totalItems'] ?? 0}',
                        icon: Icons.library_books,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _StatCard(
                        title: 'Lendo',
                        value: '${stats['readingCount'] ?? 0}',
                        icon: Icons.bookmark,
                        color: Colors.orange,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _StatCard(
                        title: 'Lidos',
                        value: '${stats['readCount'] ?? 0}',
                        icon: Icons.check_circle,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          // Lista de itens recentes
          Expanded(
            child: StreamBuilder<List<ItemModel>>(
              stream: firestoreService.getUserItems(user.uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
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
                        Icon(Icons.library_books, size: 80, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'Nenhum item adicionado ainda',
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Toque no botão + para adicionar seu primeiro mangá ou livro',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length > 5 ? 5 : items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return _ItemCard(item: item);
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const SearchScreen()),
          );
        },
        tooltip: 'Adicionar item',
        child: const Icon(Icons.add),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });

          switch (index) {
            case 0:
              // Já estamos na tela inicial
              break;
            case 1:
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ItemListScreen()),
              );
              break;
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Início'),
          BottomNavigationBarItem(icon: Icon(Icons.list), label: 'Meus Itens'),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: TextStyle(fontSize: 12, color: color.withOpacity(0.8)),
          ),
        ],
      ),
    );
  }
}

class _ItemCard extends StatelessWidget {
  final ItemModel item;

  const _ItemCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundImage: item.imageUrl != null
              ? NetworkImage(item.imageUrl!)
              : null,
          child: item.imageUrl == null ? Text(item.displayType[0]) : null,
        ),
        title: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.displayType),
            if (item.displayCurrentPosition.isNotEmpty)
              Text(
                item.displayCurrentPosition,
                style: const TextStyle(fontSize: 12),
              ),
          ],
        ),
        trailing: Container(
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
        onTap: () {
          // TODO: Navegar para tela de detalhes do item
        },
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
