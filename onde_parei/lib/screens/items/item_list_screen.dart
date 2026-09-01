import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/item_model.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ui_kit.dart';
import '../home/home_screen.dart';
import '../home/home_shell.dart';
import 'edit_item_screen.dart';

enum ShelfSort { recent, title, rating, progress }

extension on ShelfSort {
  String get label {
    switch (this) {
      case ShelfSort.recent:
        return 'Atualizados';
      case ShelfSort.title:
        return 'Título (A–Z)';
      case ShelfSort.rating:
        return 'Melhor nota';
      case ShelfSort.progress:
        return 'Mais avançados';
    }
  }
}

class ItemListScreen extends StatefulWidget {
  const ItemListScreen({super.key});

  @override
  State<ItemListScreen> createState() => _ItemListScreenState();
}

class _ItemListScreenState extends State<ItemListScreen>
    with AutomaticKeepAliveClientMixin {
  final _searchController = TextEditingController();

  ReadingStatus? _statusFilter;
  ItemType? _typeFilter;
  ShelfSort _sort = ShelfSort.recent;
  bool _gridView = true;
  String _query = '';

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<ItemModel> _apply(List<ItemModel> items) {
    final query = _query.toLowerCase().trim();

    final filtered = items.where((item) {
      if (_statusFilter != null && item.status != _statusFilter) return false;
      if (_typeFilter != null && item.type != _typeFilter) return false;
      if (query.isEmpty) return true;
      return item.name.toLowerCase().contains(query) ||
          (item.author ?? '').toLowerCase().contains(query);
    }).toList();

    switch (_sort) {
      case ShelfSort.recent:
        filtered.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      case ShelfSort.title:
        filtered.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
      case ShelfSort.rating:
        filtered.sort((a, b) => b.rating.compareTo(a.rating));
      case ShelfSort.progress:
        filtered.sort(
          (a, b) => (b.progress ?? -1).compareTo(a.progress ?? -1),
        );
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final theme = Theme.of(context);
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
          stream: firestore.getUserItems(user.uid),
          builder: (context, snapshot) {
            final all = snapshot.data ?? const <ItemModel>[];
            final items = _apply(all);
            final loading =
                snapshot.connectionState == ConnectionState.waiting;

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Minha estante',
                              style: theme.textTheme.headlineMedium,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              all.isEmpty
                                  ? 'Nada guardado ainda'
                                  : '${items.length} de ${all.length} títulos',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: _gridView ? 'Ver em lista' : 'Ver em grade',
                        onPressed: () => setState(() => _gridView = !_gridView),
                        icon: Icon(
                          _gridView
                              ? Icons.view_list_rounded
                              : Icons.grid_view_rounded,
                        ),
                      ),
                      PopupMenuButton<ShelfSort>(
                        tooltip: 'Ordenar',
                        icon: const Icon(Icons.swap_vert_rounded),
                        initialValue: _sort,
                        onSelected: (value) => setState(() => _sort = value),
                        itemBuilder: (_) => [
                          for (final option in ShelfSort.values)
                            PopupMenuItem(
                              value: option,
                              child: Text(option.label),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) => setState(() => _query = value),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: 'Filtrar por título ou autor…',
                      prefixIcon: const Icon(Icons.filter_alt_outlined, size: 19),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.close_rounded, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _query = '');
                              },
                            ),
                    ),
                  ),
                ),

                const SizedBox(height: 10),
                _FilterChips(
                  statusFilter: _statusFilter,
                  typeFilter: _typeFilter,
                  onStatus: (value) => setState(() {
                    _statusFilter = value;
                  }),
                  onType: (value) => setState(() {
                    _typeFilter = value;
                  }),
                ),
                const SizedBox(height: 6),

                Expanded(
                  child: loading
                      ? const Center(child: CircularProgressIndicator())
                      : items.isEmpty
                      ? _emptyState(all.isEmpty)
                      : _gridView
                      ? _buildGrid(items)
                      : _buildList(items, firestore),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _emptyState(bool shelfIsEmpty) {
    if (shelfIsEmpty) {
      return EmptyState(
        icon: Icons.auto_stories_rounded,
        title: 'Estante vazia',
        message: 'Adicione o primeiro título e comece a acompanhar sua leitura.',
        action: FilledButton.icon(
          onPressed: () => HomeShell.of(context)?.openSearch(),
          icon: const Icon(Icons.search_rounded, size: 18),
          label: const Text('Explorar títulos'),
        ),
      );
    }

    return EmptyState(
      icon: Icons.filter_alt_off_rounded,
      title: 'Nenhum título com esses filtros',
      message: 'Ajuste a busca ou limpe os filtros para ver a estante inteira.',
      action: OutlinedButton.icon(
        onPressed: () {
          _searchController.clear();
          setState(() {
            _query = '';
            _statusFilter = null;
            _typeFilter = null;
          });
        },
        icon: const Icon(Icons.restart_alt_rounded, size: 18),
        label: const Text('Limpar filtros'),
      ),
    );
  }

  Widget _buildGrid(List<ItemModel> items) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 130,
        crossAxisSpacing: 12,
        mainAxisSpacing: 14,
        childAspectRatio: 0.58,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) => ShelfCoverTile(item: items[index]),
    );
  }

  Widget _buildList(List<ItemModel> items, FirestoreService firestore) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final item = items[index];
        return _ItemRow(
          item: item,
          onEdit: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => EditItemScreen(item: item)),
          ),
          onDelete: () => _confirmDelete(context, firestore, item),
        );
      },
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    FirestoreService firestore,
    ItemModel item,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remover da estante'),
        content: Text('Deseja remover "${item.name}" da sua estante?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Manter'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remover'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      await firestore.deleteItem(item.id);
      if (context.mounted) {
        AppSnack.show(
          context,
          'Removido da estante.',
          icon: Icons.delete_outline_rounded,
        );
      }
    } catch (e) {
      if (context.mounted) AppSnack.error(context, '$e');
    }
  }
}

// ─── Chips de filtro ──────────────────────────────────────────────────────────

class _FilterChips extends StatelessWidget {
  final ReadingStatus? statusFilter;
  final ItemType? typeFilter;
  final ValueChanged<ReadingStatus?> onStatus;
  final ValueChanged<ItemType?> onType;

  const _FilterChips({
    required this.statusFilter,
    required this.typeFilter,
    required this.onStatus,
    required this.onType,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          ChoiceChip(
            label: const Text('Tudo'),
            selected: statusFilter == null && typeFilter == null,
            onSelected: (_) {
              onStatus(null);
              onType(null);
            },
          ),
          const SizedBox(width: 8),
          for (final status in ReadingStatusX.displayOrder) ...[
            ChoiceChip(
              avatar: Icon(
                StatusPill.iconOf(status),
                size: 14,
                color: StatusPill.colorOf(status),
              ),
              label: Text(status.label),
              selected: statusFilter == status,
              onSelected: (selected) {
                onType(null);
                onStatus(selected ? status : null);
              },
            ),
            const SizedBox(width: 8),
          ],
          for (final type in ItemType.values) ...[
            ChoiceChip(
              label: Text(type.label),
              selected: typeFilter == type,
              onSelected: (selected) {
                onStatus(null);
                onType(selected ? type : null);
              },
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

// ─── Linha da lista ───────────────────────────────────────────────────────────

class _ItemRow extends StatelessWidget {
  final ItemModel item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ItemRow({
    required this.item,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final progress = item.progress;

    return Material(
      color: scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(AppRadius.md),
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
                width: 56,
                height: 84,
                decodeWidth: 120,
                fallbackIcon: item.type.isBook
                    ? Icons.menu_book_rounded
                    : Icons.import_contacts_rounded,
              ),
              const SizedBox(width: 12),
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
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        TypeBadge.forItem(item, compact: true),
                        StatusPill(status: item.status, compact: true),
                        if (item.rating > 0)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.star_rounded,
                                size: 13,
                                color: AppColors.gold,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                item.rating.toStringAsFixed(1),
                                style: theme.textTheme.labelSmall,
                              ),
                            ],
                          ),
                      ],
                    ),
                    if ((item.author ?? '').isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        item.author!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                    if (item.displayCurrentPosition.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        item.displayCurrentPosition,
                        style: theme.textTheme.labelSmall,
                      ),
                    ],
                    if (progress != null) ...[
                      const SizedBox(height: 7),
                      ReadingProgressBar(
                        value: progress,
                        color: StatusPill.colorOf(item.status),
                        height: 4,
                      ),
                    ],
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded, size: 20),
                onSelected: (value) {
                  if (value == 'edit') onEdit();
                  if (value == 'delete') onDelete();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'edit',
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      leading: Icon(Icons.edit_outlined, size: 18),
                      title: Text('Editar'),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      leading: Icon(Icons.delete_outline_rounded, size: 18),
                      title: Text('Remover'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
