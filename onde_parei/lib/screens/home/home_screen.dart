import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/item_model.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/adaptive_network_image.dart';
import '../../widgets/ui_kit.dart';
import '../items/edit_item_screen.dart';
import 'home_shell.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.read<AuthService>().currentUser;
    final firestore = context.read<FirestoreService>();

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Usuário não autenticado')),
      );
    }

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: StreamBuilder<List<ItemModel>>(
          // Uma única assinatura alimenta cabeçalho, estatísticas e listas.
          // Antes havia também um `get()` completo só para as estatísticas.
          stream: firestore.getUserItems(user.uid),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const _HomeSkeleton();
            }

            if (snapshot.hasError) {
              return EmptyState(
                icon: Icons.error_outline_rounded,
                title: 'Não deu para abrir a estante',
                message: '${snapshot.error}',
              );
            }

            final items = snapshot.data ?? const <ItemModel>[];
            final stats = FirestoreService.statsFrom(items);
            final reading = items
                .where((i) => i.status == ReadingStatus.reading)
                .toList();

            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: _Greeting(
                    email: user.email ?? '',
                    displayName: user.displayName,
                  ),
                ),
                SliverToBoxAdapter(child: _StatsRow(stats: stats)),

                if (items.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyState(
                      icon: Icons.auto_stories_rounded,
                      title: 'Sua estante está em branco',
                      message:
                          'Que história vai ser a primeira? Busque um título '
                          'e guarde na estante para nunca mais esquecer onde parou.',
                      action: FilledButton.icon(
                        onPressed: () => HomeShell.of(context)?.openSearch(),
                        icon: const Icon(Icons.search_rounded, size: 18),
                        label: const Text('Explorar títulos'),
                      ),
                    ),
                  ),

                if (reading.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: SectionHeader(
                      title: 'Continuar lendo',
                      subtitle: reading.length == 1
                          ? '1 leitura em andamento'
                          : '${reading.length} leituras em andamento',
                    ),
                  ),
                  SliverToBoxAdapter(child: _ContinueReadingRow(items: reading)),
                ],

                if (items.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: SectionHeader(
                      title: 'Minha estante',
                      subtitle: 'Atualizados recentemente',
                      action: TextButton.icon(
                        onPressed: () => HomeShell.of(context)?.goToTab(1),
                        icon: const Icon(Icons.grid_view_rounded, size: 16),
                        label: const Text('Ver tudo'),
                      ),
                    ),
                  ),
                  _ShelfGrid(items: items.take(12).toList()),
                ],

                const SliverToBoxAdapter(child: SizedBox(height: 110)),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ─── Saudação ─────────────────────────────────────────────────────────────────

class _Greeting extends StatelessWidget {
  final String email;
  final String? displayName;

  const _Greeting({required this.email, this.displayName});

  String get _name {
    final name = (displayName ?? '').trim();
    if (name.isNotEmpty) return name.split(' ').first;
    final local = email.split('@').first.trim();
    if (local.isEmpty) return 'leitor';
    return local[0].toUpperCase() + local.substring(1);
  }

  String get _salutation {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Bom dia';
    if (hour < 18) return 'Boa tarde';
    return 'Boa noite';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$_salutation, $_name',
                  style: theme.textTheme.headlineMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'Onde você parou hoje?',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () => HomeShell.of(context)?.goToTab(3),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: scheme.primaryContainer,
                border: Border.all(
                  color: scheme.primary.withValues(alpha: 0.4),
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                _name.isNotEmpty ? _name[0].toUpperCase() : '?',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: scheme.onPrimaryContainer,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Estatísticas ─────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final Map<String, dynamic> stats;

  const _StatsRow({required this.stats});

  @override
  Widget build(BuildContext context) {
    final average = (stats['averageRating'] as double?) ?? 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: _StatCard(
              value: '${stats['totalItems'] ?? 0}',
              label: 'na estante',
              icon: Icons.library_books_rounded,
              color: AppColors.statusWant,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _StatCard(
              value: '${stats['readingCount'] ?? 0}',
              label: 'lendo',
              icon: Icons.auto_stories_rounded,
              color: AppColors.statusReading,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _StatCard(
              value: '${stats['readCount'] ?? 0}',
              label: 'concluídos',
              icon: Icons.check_circle_rounded,
              color: AppColors.statusRead,
            ),
          ),
          if (average > 0) ...[
            const SizedBox(width: 10),
            Expanded(
              child: _StatCard(
                value: average.toStringAsFixed(1),
                label: 'nota média',
                icon: Icons.star_rounded,
                color: AppColors.gold,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}

// ─── Continuar lendo ──────────────────────────────────────────────────────────

class _ContinueReadingRow extends StatelessWidget {
  final List<ItemModel> items;

  const _ContinueReadingRow({required this.items});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 178,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) =>
            _ContinueReadingCard(item: items[index]),
      ),
    );
  }
}

class _ContinueReadingCard extends StatelessWidget {
  final ItemModel item;

  const _ContinueReadingCard({required this.item});

  Future<void> _advance(BuildContext context) async {
    final firestore = context.read<FirestoreService>();
    final current = item.currentValue ?? 0;
    final field = item.type.countsChapters ? 'currentChapter' : 'currentPage';
    final next = current + 1;

    try {
      await firestore.updateFields(item.id, {field: '$next'});
      if (context.mounted) {
        AppSnack.show(
          context,
          '${item.unitLabel} $next marcado em "${item.name}"',
          icon: Icons.bookmark_added_rounded,
        );
      }
    } catch (e) {
      if (context.mounted) AppSnack.error(context, '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final progress = item.progress;

    return SizedBox(
      width: 268,
      child: Material(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => EditItemScreen(item: item)),
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: scheme.outlineVariant),
            ),
            padding: const EdgeInsets.all(11),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CoverArt(
                  imageUrl: item.imageUrl,
                  title: item.name,
                  width: 66,
                  height: 100,
                  decodeWidth: 140,
                  fallbackIcon: item.type.isBook
                      ? Icons.menu_book_rounded
                      : Icons.import_contacts_rounded,
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 5),
                      TypeBadge.forItem(item, compact: true),
                      const Spacer(),
                      Text(
                        item.displayCurrentPosition.isEmpty
                            ? 'Ainda não começou'
                            : item.displayCurrentPosition,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall,
                      ),
                      const SizedBox(height: 6),
                      if (progress != null) ...[
                        ReadingProgressBar(
                          value: progress,
                          color: AppColors.statusReading,
                        ),
                        const SizedBox(height: 8),
                      ],
                      SizedBox(
                        height: 30,
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => _advance(context),
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
                            textStyle: theme.textTheme.labelSmall,
                          ),
                          icon: const Icon(Icons.add_rounded, size: 14),
                          label: Text(
                            item.type.countsChapters ? '+1 cap.' : '+1 pág.',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Grade da estante ─────────────────────────────────────────────────────────

class _ShelfGrid extends StatelessWidget {
  final List<ItemModel> items;

  const _ShelfGrid({required this.items});

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 130,
          crossAxisSpacing: 12,
          mainAxisSpacing: 14,
          childAspectRatio: 0.58,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) => ShelfCoverTile(item: items[index]),
          childCount: items.length,
        ),
      ),
    );
  }
}

/// Capa da estante com selo de status e barra de progresso.
class ShelfCoverTile extends StatelessWidget {
  final ItemModel item;

  const ShelfCoverTile({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = item.progress;
    final statusColor = StatusPill.colorOf(item.status);

    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => EditItemScreen(item: item)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                CoverArt(
                  imageUrl: item.imageUrl,
                  title: item.name,
                  decodeWidth: 200,
                  fallbackIcon: item.type.isBook
                      ? Icons.menu_book_rounded
                      : Icons.import_contacts_rounded,
                ),
                Positioned(
                  top: 5,
                  right: 5,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: statusColor,
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x66000000),
                          blurRadius: 4,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Icon(
                      StatusPill.iconOf(item.status),
                      size: 11,
                      color: const Color(0xFF14100B),
                    ),
                  ),
                ),
                if (progress != null)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: ReadingProgressBar(
                      value: progress,
                      color: statusColor,
                      height: 4,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 7),
          Text(
            item.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Skeleton inicial ─────────────────────────────────────────────────────────

class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      children: [
        const SkeletonBox(height: 28, width: 210),
        const SizedBox(height: 18),
        Row(
          children: const [
            Expanded(child: SkeletonBox(height: 82, radius: AppRadius.md)),
            SizedBox(width: 10),
            Expanded(child: SkeletonBox(height: 82, radius: AppRadius.md)),
            SizedBox(width: 10),
            Expanded(child: SkeletonBox(height: 82, radius: AppRadius.md)),
          ],
        ),
        const SizedBox(height: 26),
        const SkeletonBox(height: 20, width: 160),
        const SizedBox(height: 14),
        const SkeletonBox(height: 122, radius: AppRadius.md),
      ],
    );
  }
}
