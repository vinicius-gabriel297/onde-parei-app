import 'package:flutter/material.dart';
import '../../services/api_service.dart';
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
  List<SearchResult> _searchResults = [];
  List<SearchResult> _filteredResults = [];
  bool _isLoading = false;
  String? _errorMessage;
  String _selectedTypeFilter = 'todos'; // 'todos', 'manga', 'book'

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterResults() {
    setState(() {
      if (_selectedTypeFilter == 'todos') {
        _filteredResults = _searchResults;
      } else {
        _filteredResults = _searchResults
            .where((result) => result.type == _selectedTypeFilter)
            .toList();
      }
    });
  }

  Future<void> _search() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _errorMessage = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await ApiService.searchAll(query);

      setState(() {
        _searchResults = results;
        _filteredResults = results; // Initialize filtered results
        _filterResults(); // Apply current filter
        _isLoading = false;
      });
    } catch (e) {
      String errorMessage = 'Erro na busca: $e';

      // Melhorar mensagens para rate limiting
      if (e.toString().contains('429')) {
        errorMessage =
            '✅ API com limite de uso, mas app funciona com dados de exemplo!';
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
        title: const Text('Buscar Mangá/Livro'),
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
                hintText: 'Digite o nome do mangá ou livro...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_searchController.text.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchResults = [];
                            _errorMessage = null;
                          });
                        },
                      ),
                    IconButton(
                      icon: const Icon(Icons.search),
                      onPressed: _search,
                    ),
                  ],
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onSubmitted: (_) => _search(),
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
                  Text('Buscando...'),
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
                          Icons.search,
                          size: 80,
                          color: colorScheme.secondary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Digite algo para buscar',
                          style: TextStyle(
                            fontSize: 18,
                            color: colorScheme.secondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Encontre mangás e livros para adicionar à sua coleção',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: colorScheme.secondary,
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
