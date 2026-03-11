import 'package:flutter/material.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../services/firestore_service.dart';
import '../../models/api_models.dart';
import '../items/add_item_screen.dart';
import '../../widgets/adaptive_network_image.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  int _searchRequestId = 0;

  List<SearchResult> _searchResults = [];
  List<SearchResult> _filteredResults = [];
  bool _isLoading = false;
  String? _errorMessage;
  String _selectedTypeFilter = 'todos'; // 'todos', 'manga', 'book'

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _filterResults() {
    if (!mounted) return;
    setState(_applyFilterInMemory);
  }

  void _applyFilterInMemory() {
    if (_selectedTypeFilter == 'todos') {
      _filteredResults = _searchResults;
    } else {
      _filteredResults = _searchResults
          .where((result) => result.type == _selectedTypeFilter)
          .toList();
    }
  }

  void _onSearchChanged(String rawValue) {
    final query = rawValue.trim();

    // Atualiza estado do ícone de limpar durante digitação
    if (mounted) {
      setState(() {});
    }

    _searchDebounce?.cancel();

    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _filteredResults = [];
        _errorMessage = null;
        _isLoading = false;
      });
      return;
    }

    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      _search(queryOverride: query);
    });
  }

  Future<void> _search({String? queryOverride}) async {
    final query = (queryOverride ?? _searchController.text).trim();
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _filteredResults = [];
        _errorMessage = null;
      });
      return;
    }

    final currentRequestId = ++_searchRequestId;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final firestoreService = Provider.of<FirestoreService>(
        context,
        listen: false,
      );

      final onlyBooks = _selectedTypeFilter == 'book';

      // Disparar buscas de mangá/manhwa em paralelo enquanto roda o catálogo
      // (puladas se o filtro for apenas livros — evita latência desnecessária)
      Future<List<SearchResult>>? mangaFuture;
      Future<List<SearchResult>>? manhwaFuture;

      if (!onlyBooks) {
        mangaFuture = ApiService.searchMangas(query, limit: 4)
            .then((list) => list.map(SearchResult.fromManga).toList())
            .catchError((_) => <SearchResult>[]);

        manhwaFuture = ApiService.searchManhwaManhua(query, limit: 6)
            .then((list) => list.map(SearchResult.fromMangaDex).toList())
            .catchError((_) => <SearchResult>[]);
      }

      // 1. Buscar no catálogo local (Firestore) — normalmente < 500ms
      final catalogBooks = await firestoreService.searchBookCatalog(
        query,
        limit: 10,
      );

      if (!mounted || currentRequestId != _searchRequestId) return;

      // 2. Só chama a API de livros se o catálogo devolveu poucos resultados
      List<SearchResult> apiBooks = [];
      if (catalogBooks.length < 5) {
        final needed = 10 - catalogBooks.length;
        final catalogIds = catalogBooks.map((r) => r.id).toSet();

        apiBooks = await ApiService.searchBooks(query, maxResults: needed + 5)
            .then((list) => list.map(SearchResult.fromBook).toList())
            .catchError((_) => <SearchResult>[]);

        // Deduplica: remove livros que já estão no catálogo
        apiBooks = apiBooks.where((r) => !catalogIds.contains(r.id)).toList();
      }

      if (!mounted || currentRequestId != _searchRequestId) return;

      // 3. Aguardar mangá/manhwa (que já corriam em paralelo)
      final mangaResults =
          await (mangaFuture ?? Future.value(<SearchResult>[]));
      final manhwaResults =
          await (manhwaFuture ?? Future.value(<SearchResult>[]));

      if (!mounted || currentRequestId != _searchRequestId) return;

      // 4. Montar lista final e ordenar
      final allResults = [
        ...catalogBooks,
        ...apiBooks,
        ...mangaResults,
        ...manhwaResults,
      ];

      if (allResults.isEmpty) {
        setState(() {
          _searchResults = [];
          _filteredResults = [];
          _errorMessage = 'Nenhum resultado encontrado.';
          _isLoading = false;
        });
        return;
      }

      allResults.sort((a, b) {
        const order = {'book': 1, 'manga': 2, 'manhwa': 3};
        final typeCompare = (order[a.type] ?? 999).compareTo(
          order[b.type] ?? 999,
        );
        if (typeCompare != 0) return typeCompare;

        if (a.type == 'book') {
          final aRatings = (a.rawData?['ratingsCount'] as num?)?.toInt() ?? 0;
          final bRatings = (b.rawData?['ratingsCount'] as num?)?.toInt() ?? 0;
          if (aRatings != bRatings) return bRatings.compareTo(aRatings);
        }
        return a.title.toLowerCase().compareTo(b.title.toLowerCase());
      });

      setState(() {
        _searchResults = allResults;
        _applyFilterInMemory();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted || currentRequestId != _searchRequestId) return;

      String errorMessage = 'Erro na busca: $e';
      if (e.toString().contains('429')) {
        errorMessage =
            'Limite de requisições atingido. Tente novamente em breve.';
      } else if (e.toString().contains('Tempo limite')) {
        errorMessage = 'Tempo limite excedido. Verifique sua conexão.';
      } else if (e.toString().contains('Erro de conexão')) {
        errorMessage = 'Erro de conexão. Verifique sua internet.';
      }

      setState(() {
        _errorMessage = errorMessage;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Explorar Títulos'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          // Filtro de tipo
          PopupMenuButton<String>(
            onSelected: (value) {
              setState(() {
                _selectedTypeFilter = value;
                _filterResults();
              });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text(
                    _selectedTypeFilter == 'todos'
                        ? 'Todos'
                        : _selectedTypeFilter == 'manga'
                        ? 'Mangás'
                        : 'Livros',
                    style: TextStyle(
                      fontSize: 14,
                      color: colorScheme.onPrimary,
                    ),
                  ),
                  Icon(Icons.arrow_drop_down, color: colorScheme.onPrimary),
                ],
              ),
            ),
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'todos', child: Text('Todos')),
              const PopupMenuItem(value: 'manga', child: Text('Mangás')),
              const PopupMenuItem(value: 'book', child: Text('Livros')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Campo de busca
          Container(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Buscar em mundos e galáxias...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_searchController.text.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchDebounce?.cancel();
                          _searchController.clear();
                          setState(() {
                            _searchResults = [];
                            _filteredResults = [];
                            _errorMessage = null;
                            _isLoading = false;
                          });
                        },
                      ),
                    IconButton(
                      icon: const Icon(Icons.search),
                      onPressed: () => _search(),
                    ),
                  ],
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onSubmitted: (_) => _search(),
              onChanged: _onSearchChanged,
            ),
          ),

          // Loading indicator
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  LinearProgressIndicator(),
                  SizedBox(height: 16),
                  Text(
                    'Vasculhando bibliotecas...',
                    style: TextStyle(fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),

          // Error message
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                _errorMessage!,
                style: TextStyle(color: colorScheme.error),
                textAlign: TextAlign.center,
              ),
            ),

          // Resultados da busca
          Expanded(
            child: _searchResults.isEmpty && !_isLoading
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_rounded,
                          size: 72,
                          color: colorScheme.primary.withValues(alpha: 0.4),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          'O que você quer descobrir hoje?',
                          style: TextStyle(
                            fontSize: 18,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Busque por título, autor ou gênero.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            fontStyle: FontStyle.italic,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filteredResults.length,
                    itemBuilder: (context, index) {
                      final result = _filteredResults[index];
                      return _SearchResultCard(
                        result: result,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  AddItemScreen(searchResult: result),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _SearchResultCard extends StatelessWidget {
  final SearchResult result;
  final VoidCallback onTap;

  const _SearchResultCard({required this.result, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

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
                  color: colorScheme.surface,
                ),
                child: result.imageUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: AdaptiveNetworkImage(
                          imageUrl: result.imageUrl!,
                          fit: BoxFit.cover,
                          fallback: Container(
                            color: colorScheme.surface,
                            child: Icon(
                              result.type == 'manga'
                                  ? Icons.book
                                  : Icons.menu_book,
                              color: colorScheme.secondary,
                            ),
                          ),
                        ),
                      )
                    : Icon(
                        result.type == 'manga' ? Icons.book : Icons.menu_book,
                        color: colorScheme.secondary,
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
                      result.title,
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
                        color: result.type == 'manga'
                            ? const Color(0xFF4F6C73).withValues(alpha: 0.16)
                            : const Color(0xFF697345).withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        result.type == 'manga' ? 'Mangá' : 'Livro',
                        style: TextStyle(
                          fontSize: 12,
                          color: result.type == 'manga'
                              ? const Color(0xFF4F6C73)
                              : const Color(0xFF697345),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),

                    // Autores (se disponível)
                    if (result.authors != null && result.authors!.isNotEmpty)
                      Text(
                        result.authors!.join(', '),
                        style: TextStyle(
                          fontSize: 14,
                          color: colorScheme.secondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),

                    // Descrição (se disponível)
                    if (result.description != null &&
                        result.description!.isNotEmpty)
                      Text(
                        result.description!,
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.secondary.withValues(alpha: 0.8),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),

              // Botão de ação
              IconButton(
                onPressed: onTap,
                icon: const Icon(Icons.add_circle),
                color: colorScheme.primary,
                tooltip: 'Adicionar',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
