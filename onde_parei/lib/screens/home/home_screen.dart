import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../models/item_model.dart';
import '../../widgets/adaptive_network_image.dart';
import '../items/item_list_screen.dart';
import '../items/edit_item_screen.dart';
import '../search/search_screen.dart';
import '../settings/settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final authService = Provider.of<AuthService>(context);
    final firestoreService = Provider.of<FirestoreService>(context);

    final user = authService.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.menu_book_rounded,
              color: colorScheme.onPrimary,
              size: 22,
            ),
            const SizedBox(width: 8),
            Text('Onde Parei?', style: TextStyle(color: colorScheme.onPrimary)),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.person_outline_rounded,
              color: colorScheme.onPrimary,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
            tooltip: 'Meu Perfil',
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 1000;
          final isWideDesktop = constraints.maxWidth >= 1400;

          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isDesktop ? 1400 : double.infinity,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Estatísticas compactas
                  FutureBuilder<Map<String, dynamic>>(
                    future: firestoreService.getUserStats(user!.uid),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const SizedBox(
                          height: 3,
                          child: LinearProgressIndicator(),
                        );
                      }
                      final stats = snapshot.data ?? {};
                      return _StatsRow(stats: stats, isDesktop: isDesktop);
                    },
                  ),

                  // Cabeçalho da Estante
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      isDesktop ? 24 : 16,
                      isDesktop ? 20 : 14,
                      isDesktop ? 24 : 16,
                      4,
                    ),
                    child: Row(
                      children: [
                        Text(
                          'Minha Estante',
                          style: GoogleFonts.crimsonText(
                            fontSize: isDesktop ? 26 : 22,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const Spacer(),
                        TextButton.icon(
                          icon: const Icon(Icons.list_rounded, size: 18),
                          label: const Text('Ver lista'),
                          style: TextButton.styleFrom(
                            foregroundColor: colorScheme.primary,
                            textStyle: GoogleFonts.libreFranklin(fontSize: 13),
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const ItemListScreen(),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                  // Grade de capas — estante visual
                  Expanded(
                    child: StreamBuilder<List<ItemModel>>(
                      stream: firestoreService.getUserItems(user.uid),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        if (snapshot.hasError) {
                          return Center(
                            child: Text(
                              'Erro ao carregar itens: ${snapshot.error}',
                              style: TextStyle(color: colorScheme.error),
                            ),
                          );
                        }

                        final items = snapshot.data ?? [];

                        if (items.isEmpty) {
                          return _EmptyShelf(isDesktop: isDesktop);
                        }

                        int crossAxisCount;
                        if (isWideDesktop) {
                          crossAxisCount = 6;
                        } else if (isDesktop) {
                          crossAxisCount = 4;
                        } else {
                          crossAxisCount = 3;
                        }

                        return GridView.builder(
                          padding: EdgeInsets.fromLTRB(
                            isDesktop ? 24 : 12,
                            8,
                            isDesktop ? 24 : 12,
                            24,
                          ),
                          itemCount: items.length,
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: crossAxisCount,
                                crossAxisSpacing: isDesktop ? 14 : 10,
                                mainAxisSpacing: isDesktop ? 14 : 10,
                                childAspectRatio: 0.62,
                              ),
                          itemBuilder: (context, index) {
                            return _BookCoverCard(
                              item: items[index],
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        EditItemScreen(item: items[index]),
                                  ),
                                );
                              },
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const SearchScreen()),
          );
        },
        tooltip: 'Explorar & Adicionar',
        child: const Icon(Icons.add_rounded),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
          switch (index) {
            case 0:
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
          BottomNavigationBarItem(
            icon: Icon(Icons.home_rounded),
            label: 'Início',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.library_books_rounded),
            label: 'Minha Estante',
          ),
        ],
      ),
    );
  }
}

// ─── Stats Row ───────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final Map<String, dynamic> stats;
  final bool isDesktop;

  const _StatsRow({required this.stats, this.isDesktop = false});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 24 : 16,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: colorScheme.primary.withValues(alpha: 0.2)),
        ),
      ),
      child: Row(
        children: [
          _StatChip(
            label: '${stats['totalItems'] ?? 0} títulos',
            icon: Icons.library_books_rounded,
            color: const Color(0xFF6A9E96),
          ),
          const SizedBox(width: 10),
          _StatChip(
            label: '${stats['readingCount'] ?? 0} lendo',
            icon: Icons.bookmark_rounded,
            color: const Color(0xFFC8A45A),
          ),
          const SizedBox(width: 10),
          _StatChip(
            label: '${stats['readCount'] ?? 0} concluídos',
            icon: Icons.check_circle_rounded,
            color: const Color(0xFF587A52),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;

  const _StatChip({
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.libreFranklin(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Empty Shelf ──────────────────────────────────────────────────────────────

class _EmptyShelf extends StatelessWidget {
  final bool isDesktop;

  const _EmptyShelf({this.isDesktop = false});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: EdgeInsets.all(isDesktop ? 48 : 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.menu_book_rounded,
              size: isDesktop ? 96 : 72,
              color: colorScheme.primary.withValues(alpha: 0.45),
            ),
            SizedBox(height: isDesktop ? 24 : 18),
            Text(
              'Sua estante está em branco...',
              textAlign: TextAlign.center,
              style: GoogleFonts.crimsonText(
                fontSize: isDesktop ? 26 : 22,
                fontWeight: FontWeight.w500,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Que história vai ser a primeira?',
              textAlign: TextAlign.center,
              style: GoogleFonts.libreBaskerville(
                fontSize: isDesktop ? 16 : 14,
                color: colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
            SizedBox(height: isDesktop ? 32 : 24),
            Text(
              'Toque no  +  para explorar títulos',
              textAlign: TextAlign.center,
              style: GoogleFonts.libreFranklin(
                fontSize: 13,
                color: colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Book Cover Card ──────────────────────────────────────────────────────────

class _BookCoverCard extends StatelessWidget {
  final ItemModel item;
  final VoidCallback onTap;

  const _BookCoverCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isReading = item.status == ReadingStatus.reading;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Capa do livro
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: item.imageUrl != null
                  ? AdaptiveNetworkImage(
                      imageUrl: item.imageUrl!,
                      fit: BoxFit.cover,
                      fallback: _buildFallbackCover(colorScheme),
                    )
                  : _buildFallbackCover(colorScheme),
            ),

            // Gradiente + título na base
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(8),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.75),
                      ],
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(6, 16, 6, 6),
                  child: Text(
                    item.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.libreFranklin(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                      height: 1.3,
                    ),
                  ),
                ),
              ),
            ),

            // Indicador "Lendo" no canto superior direito
            if (isReading)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFC8A45A),
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(3),
                  child: const Icon(
                    Icons.bookmark_rounded,
                    size: 12,
                    color: Color(0xFF1A1410),
                  ),
                ),
              ),

            // Badge "Concluído"
            if (item.status == ReadingStatus.read)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF587A52),
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(3),
                  child: const Icon(
                    Icons.check_rounded,
                    size: 12,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFallbackCover(ColorScheme colorScheme) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: const Color(0xFF2C2318),
        border: Border.all(
          color: const Color(0xFFC8A45A).withValues(alpha: 0.3),
        ),
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            item.type == ItemType.manga
                ? Icons.menu_book_rounded
                : Icons.book_rounded,
            color: const Color(0xFFC8A45A).withValues(alpha: 0.6),
            size: 28,
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              item.name,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.libreFranklin(
                fontSize: 9,
                color: const Color(0xFFB89E78),
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
