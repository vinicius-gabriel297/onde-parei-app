import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

import '../services/api_service.dart';
import '../models/reading_item.dart';
import 'add_item_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchController = TextEditingController();
  final _apiService = ApiService();
  List<Map<String, dynamic>> _mangaResults = [];
  List<Map<String, dynamic>> _bookResults = [];
  bool _isLoading = false;
  bool _isMangaSelected = true;
  String _error = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _search() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isLoading = true;
      _error = '';
      _mangaResults = [];
      _bookResults = [];
    });

    try {
      if (_isMangaSelected) {
        _mangaResults = await _apiService.searchManga(query);
      } else {
        _bookResults = await _apiService.searchBooks(query);
      }
    } catch (e) {
      setState(() {
        _error = _formatErrorMessage(e);
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _addItem(Map<String, dynamic> itemData) {
    ReadingItem item;
    if (_isMangaSelected) {
      item = _apiService.mangaFromApi(itemData);
    } else {
      item = _apiService.bookFromApi(itemData);
    }

    // Set the current user ID
    final authProvider = context.read<AuthProvider>();
    item = item.copyWith(userId: authProvider.user!.uid);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddItemScreen(existingItem: item),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Buscar'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: _isMangaSelected
                        ? 'Buscar mangá...'
                        : 'Buscar livro...',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.search),
                      onPressed: _search,
                    ),
                  ),
                  onSubmitted: (_) => _search(),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isMangaSelected
                            ? null
                            : () => setState(() => _isMangaSelected = true),
                        style: _isMangaSelected
                            ? ElevatedButton.styleFrom(
                                backgroundColor: Theme.of(context).primaryColor)
                            : null,
                        child: const Text('Mangá'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: !_isMangaSelected
                            ? null
                            : () => setState(() => _isMangaSelected = false),
                        style: !_isMangaSelected
                            ? ElevatedButton.styleFrom(
                                backgroundColor: Theme.of(context).primaryColor)
                            : null,
                        child: const Text('Livro'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error, color: Colors.red, size: 64),
                      const SizedBox(height: 16),
                      Text(
                        _error,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _search,
                        child: const Text('Tentar novamente'),
                      ),
                    ],
                  ),
                )
              : _buildResultsList(),
    );
  }

  Widget _buildResultsList() {
    final results = _isMangaSelected ? _mangaResults : _bookResults;

    if (results.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Nenhum resultado encontrado',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'Digite algo na busca acima',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (context, index) {
        final item = results[index];
        String imageUrl = '';
        String title = 'Título desconhecido';

        try {
          if (_isMangaSelected) {
            imageUrl = item['images']?['jpg']?['large_image_url'] ??
                item['images']?['jpg']?['image_url'] ??
                item['images']?['jpg']?['small_image_url'] ??
                '';
            title = item['title'] ?? 'Título desconhecido';
          } else {
            final coverId = item['cover_i'];
            if (coverId != null) {
              imageUrl = 'https://covers.openlibrary.org/b/id/$coverId-M.jpg';
            }
            title = item['title'] ?? 'Título desconhecido';
          }
        } catch (e) {
          // Use default values in case of error
        }

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: ListTile(
            leading: CircleAvatar(
              backgroundImage:
                  imageUrl.isNotEmpty ? NetworkImage(imageUrl) : null,
              child: imageUrl.isEmpty ? const Icon(Icons.book) : null,
            ),
            title: Text(title),
            subtitle: const Text('Autor desconhecido'),
            trailing: ElevatedButton(
              onPressed: () => _addItem(item),
              child: const Text('Adicionar'),
            ),
          ),
        );
      },
    );
  }

  String _formatErrorMessage(Object error) {
    final message = error.toString().replaceFirst('Exception: ', '').trim();
    if (message.isEmpty) {
      return 'Não foi possível concluir a busca agora. Tente novamente em instantes.';
    }
    return message;
  }
}
