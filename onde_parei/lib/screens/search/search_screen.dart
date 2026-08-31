import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/api_models.dart';
import '../../models/item_model.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../services/search_history_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/adaptive_network_image.dart';
import '../../widgets/ui_kit.dart';
import '../items/add_item_screen.dart';

const _suggestions = <String>[
  'Solo Leveling',
  'One Piece',
  'Tower of God',
  'Duna',
  'O Nome do Vento',
  'Berserk',
  'Chainsaw Man',
  'A Revolução dos Bichos',
];

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen>
    with AutomaticKeepAliveClientMixin {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();

  Timer? _debounce;
  StreamSubscription<SearchSnapshot>? _subscription;

  SearchSnapshot? _snapshot;
  bool _isSearching = false;
  String _activeQuery = '';
  SearchScope _scope = SearchScope.all;
  List<String> _recent = const [];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadRecent();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _subscription?.cancel();
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadRecent() async {
    final history = context.read<SearchHistoryService>();
    final recent = await history.load();
    if (mounted) setState(() => _recent = recent);
  }

  void _onQueryChanged(String value) {
    setState(() {});
    _debounce?.cancel();

    final query = value.trim();
    if (query.length < 2) {
      _subscription?.cancel();
      setState(() {
        _snapshot = null;
        _isSearching = false;
        _activeQuery = '';
      });
      return;
    }

    _debounce = Timer(
      const Duration(milliseconds: 280),
      () => _startSearch(query),
    );
  }

  void _startSearch(String query, {bool saveHistory = true}) {
    final trimmed = query.trim();
    if (trimmed.length < 2) return;

    _debounce?.cancel();
    _subscription?.cancel();

    setState(() {
      _activeQuery = trimmed;
      _isSearching = true;
      _snapshot = null;
    });

    final firestore = context.read<FirestoreService>();

    // Cada fonte que responde emite um snapshot: os primeiros resultados
    // aparecem sem esperar a API mais lenta terminar.
    _subscription =
        ApiService.searchStream(
          trimmed,
          scope: _scope,
          catalogLookup: (q) => firestore.searchBookCatalog(q, limit: 8),
        ).listen(
          (snapshot) {
            if (!mounted) return;
            setState(() {
              _snapshot = snapshot;
              _isSearching = !snapshot.isDone;
            });
          },
          onDone: () {
            if (mounted) setState(() => _isSearching = false);
          },
          onError: (_) {
            if (mounted) setState(() => _isSearching = false);
          },
        );

    if (saveHistory) {
      context.read<SearchHistoryService>().add(trimmed).then((recent) {
        if (mounted) setState(() => _recent = recent);
      });
    }
  }

  void _changeScope(SearchScope scope) {
    if (_scope == scope) return;
    setState(() => _scope = scope);
    if (_activeQuery.isNotEmpty) {
      _startSearch(_activeQuery, saveHistory: false);
    }
  }

  void _clear() {
    _debounce?.cancel();
    _subscription?.cancel();
    _searchController.clear();
    setState(() {
      _snapshot = null;
      _isSearching = false;
      _activeQuery = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final user = context.read<AuthService>().currentUser;
    final firestore = context.read<FirestoreService>();

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Explorar', style: theme.textTheme.headlineMedium),
                  const SizedBox(height: 2),
                  Text(
                    'Livros, mangás, manhwas e manhuas em um só lugar.',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _searchController,
                    focusNode: _focusNode,
                    textInputAction: TextInputAction.search,
                    onChanged: _onQueryChanged,
                    onSubmitted: _startSearch,
                    decoration: InputDecoration(
                      hintText: 'Buscar por título ou autor…',
                      prefixIcon: const Icon(Icons.search_rounded, size: 20),
                      suffixIcon: _searchController.text.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.close_rounded, size: 18),
                              onPressed: _clear,
                              tooltip: 'Limpar',
                            ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _ScopeSelector(scope: _scope, onChanged: _changeScope),
                ],
              ),
            ),

            _SearchProgressBar(
              snapshot: _snapshot,
              isSearching: _isSearching,
            ),

            Expanded(
              child: StreamBuilder<List<ItemModel>>(
                stream: user == null
                    ? const Stream<List<ItemModel>>.empty()
                    : firestore.getUserItems(user.uid),
                builder: (context, shelfSnapshot) {
                  final shelfTitles = <String>{
                    for (final item in shelfSnapshot.data ?? const <ItemModel>[])
                      item.name.toLowerCase().trim(),
                  };
                  return _buildBody(context, scheme, shelfTitles);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    ColorScheme scheme,
    Set<String> shelfTitles,
  ) {
    if (_activeQuery.isEmpty) {
      return _IdleView(
        recent: _recent,
        onPick: (term) {
          _searchController.text = term;
          _startSearch(term);
        },
        onClearHistory: () async {
          await context.read<SearchHistoryService>().clear();
          if (mounted) setState(() => _recent = const []);
        },
      );
    }

    final snapshot = _snapshot;

    if (snapshot == null || (snapshot.isEmpty && !snapshot.isDone)) {
      return const _ResultSkeletonList();
    }

    if (snapshot.isEmpty && snapshot.isDone) {
      final allFailed = snapshot.failedSources.length == snapshot.totalSources;
      return EmptyState(
        icon: allFailed
            ? Icons.cloud_off_rounded
            : Icons.search_off_rounded,
        title: allFailed ? 'Sem conexão com as fontes' : 'Nada encontrado',
        message: allFailed
            ? 'Não conseguimos falar com as bibliotecas agora. '
                  'Verifique a internet e tente novamente.'
            : 'Nenhum resultado para "$_activeQuery". '
                  'Tente outro termo ou o nome do autor.',
        action: FilledButton.icon(
          onPressed: () {
            ApiService.reset();
            _startSearch(_activeQuery, saveHistory: false);
          },
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: const Text('Tentar novamente'),
        ),
      );
    }

    final results = snapshot.results;

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      itemCount: results.length + (snapshot.isDone ? 0 : 1),
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        if (index >= results.length) {
          return const _ResultSkeletonCard();
        }
        final result = results[index];
        return _ResultCard(
          result: result,
          alreadyInShelf: shelfTitles.contains(
            result.title.toLowerCase().trim(),
          ),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AddItemScreen(searchResult: result),
            ),
          ),
        );
      },
    );
  }
}

// ─── Seletor de escopo ────────────────────────────────────────────────────────

class _ScopeSelector extends StatelessWidget {
  final SearchScope scope;
  final ValueChanged<SearchScope> onChanged;

  const _ScopeSelector({required this.scope, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    const options = <(SearchScope, String, IconData)>[
      (SearchScope.all, 'Tudo', Icons.auto_awesome_rounded),
      (SearchScope.books, 'Livros', Icons.menu_book_rounded),
      (SearchScope.comics, 'Mangás & Manhwas', Icons.import_contacts_rounded),
    ];

    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: options.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final (value, label, icon) = options[index];
          final selected = scope == value;
          return ChoiceChip(
            selected: selected,
            onSelected: (_) => onChanged(value),
            avatar: Icon(
              icon,
              size: 15,
              color: selected
                  ? Theme.of(context).colorScheme.onPrimaryContainer
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            label: Text(label),
          );
        },
      ),
    );
  }
}

// ─── Barra de progresso das fontes ────────────────────────────────────────────

class _SearchProgressBar extends StatelessWidget {
  final SearchSnapshot? snapshot;
  final bool isSearching;

  const _SearchProgressBar({required this.snapshot, required this.isSearching});

  @override
  Widget build(BuildContext context) {
    if (!isSearching) return const SizedBox(height: 12);

    final theme = Theme.of(context);
    final done = snapshot == null
        ? 0
        : snapshot!.totalSources - snapshot!.pendingSources;
    final total = snapshot?.totalSources ?? 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: LinearProgressIndicator(
              minHeight: 3,
              value: total == 0 ? null : done / total,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            total == 0
                ? 'Consultando bibliotecas…'
                : 'Consultando bibliotecas… $done de $total',
            style: theme.textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}

// ─── Tela inicial da busca ────────────────────────────────────────────────────

class _IdleView extends StatelessWidget {
  final List<String> recent;
  final ValueChanged<String> onPick;
  final VoidCallback onClearHistory;

  const _IdleView({
    required this.recent,
    required this.onPick,
    required this.onClearHistory,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
      children: [
        if (recent.isNotEmpty) ...[
          Row(
            children: [
              Expanded(
                child: Text(
                  'Buscas recentes',
                  style: theme.textTheme.titleSmall,
                ),
              ),
              TextButton(
                onPressed: onClearHistory,
                child: const Text('Limpar'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final term in recent)
                ActionChip(
                  avatar: const Icon(Icons.history_rounded, size: 15),
                  label: Text(term),
                  onPressed: () => onPick(term),
                ),
            ],
          ),
          const SizedBox(height: 28),
        ],
        Text('Sugestões', style: theme.textTheme.titleSmall),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final term in _suggestions)
              ActionChip(label: Text(term), onPressed: () => onPick(term)),
          ],
        ),
        const SizedBox(height: 36),
        Center(
          child: Icon(
            Icons.travel_explore_rounded,
            size: 64,
            color: theme.colorScheme.primary.withValues(alpha: 0.28),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'O que você quer descobrir hoje?',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 6),
        Text(
          'Consultamos MangaDex, Kitsu, MyAnimeList, Google Books e '
          'Open Library ao mesmo tempo — os resultados aparecem conforme '
          'cada fonte responde.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}

// ─── Card de resultado ────────────────────────────────────────────────────────

class _ResultCard extends StatelessWidget {
  final SearchResult result;
  final bool alreadyInShelf;
  final VoidCallback onTap;

  const _ResultCard({
    required this.result,
    required this.alreadyInShelf,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final typeColor = AppColors.forType(result.type);

    final meta = <String>[
      if (result.year != null && result.year!.isNotEmpty) result.year!,
      if (result.totalUnits != null && result.totalUnits! > 0)
        result.isBook
            ? '${result.totalUnits} págs'
            : '${result.totalUnits} caps',
      result.source.label,
    ];

    return Material(
      color: scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onTap,
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
                imageUrl: result.imageUrl,
                title: result.title,
                width: 58,
                height: 86,
                decodeWidth: 120,
                fallbackIcon: result.isBook
                    ? Icons.menu_book_rounded
                    : Icons.import_contacts_rounded,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        TypeBadge(
                          label: result.typeLabel,
                          color: typeColor,
                          compact: true,
                        ),
                        if (result.score != null && result.score! > 0) ...[
                          const SizedBox(width: 8),
                          Icon(
                            Icons.star_rounded,
                            size: 13,
                            color: AppColors.gold,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            result.score!.toStringAsFixed(1),
                            style: theme.textTheme.labelSmall,
                          ),
                        ],
                        if (alreadyInShelf) ...[
                          const SizedBox(width: 8),
                          Icon(
                            Icons.library_add_check_rounded,
                            size: 14,
                            color: AppColors.statusRead,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            'Na estante',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: AppColors.statusRead,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (result.authors != null &&
                        result.authors!.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        result.authors!.take(2).join(', '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      meta.join('  ·  '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant.withValues(alpha: 0.75),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              IconButton.filledTonal(
                onPressed: onTap,
                iconSize: 18,
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.add_rounded),
                tooltip: 'Adicionar à estante',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Skeletons ────────────────────────────────────────────────────────────────

class _ResultSkeletonList extends StatelessWidget {
  const _ResultSkeletonList();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      itemCount: 6,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, __) => const _ResultSkeletonCard(),
    );
  }
}

class _ResultSkeletonCard extends StatelessWidget {
  const _ResultSkeletonCard();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SkeletonBox(width: 58, height: 86, radius: AppRadius.sm),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                SkeletonBox(height: 14, width: 190),
                SizedBox(height: 10),
                SkeletonBox(height: 12, width: 90),
                SizedBox(height: 10),
                SkeletonBox(height: 11, width: 140),
                SizedBox(height: 8),
                SkeletonBox(height: 11, width: 110),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
