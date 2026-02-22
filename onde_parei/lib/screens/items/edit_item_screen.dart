import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../models/item_model.dart';

class EditItemScreen extends StatefulWidget {
  final ItemModel item;

  const EditItemScreen({super.key, required this.item});

  @override
  State<EditItemScreen> createState() => _EditItemScreenState();
}

class _EditItemScreenState extends State<EditItemScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _authorController;
  late TextEditingController _descriptionController;
  late TextEditingController _currentChapterController;
  late TextEditingController _currentPageController;

  late ItemType _selectedType;
  late ReadingStatus _selectedStatus;
  late double _rating;
  bool _isLoading = false;
  String? _errorMessage;
  final bool _isMetadataReadOnly = true;
  late String? _publishedDate;
  late List<String> _genres;
  bool _isDescriptionExpanded = false;

  @override
  void initState() {
    super.initState();
    // Inicializar controllers com os dados do item
    _nameController = TextEditingController(text: widget.item.name);
    _authorController = TextEditingController(text: widget.item.author ?? '');
    _descriptionController = TextEditingController(
      text: widget.item.description ?? '',
    );
    _currentChapterController = TextEditingController(
      text: widget.item.currentChapter,
    );
    _currentPageController = TextEditingController(
      text: widget.item.currentPage,
    );

    _selectedType = widget.item.type;
    _selectedStatus = widget.item.status;
    _rating = widget.item.rating;
    _publishedDate = widget.item.publishedDate;
    _genres = widget.item.genres ?? [];
  }

  @override
  void dispose() {
    _nameController.dispose();
    _authorController.dispose();
    _descriptionController.dispose();
    _currentChapterController.dispose();
    _currentPageController.dispose();
    super.dispose();
  }

  Future<void> _updateItem() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final firestoreService = Provider.of<FirestoreService>(
        context,
        listen: false,
      );

      final user = authService.currentUser;
      if (user == null) {
        throw Exception('Usuário não autenticado');
      }

      final updatedItem = widget.item.copyWith(
        name: _nameController.text.trim(),
        author: _authorController.text.trim().isNotEmpty
            ? _authorController.text.trim()
            : null,
        type: _selectedType,
        status: _selectedStatus,
        currentChapter: _currentChapterController.text.trim(),
        currentPage: _currentPageController.text.trim(),
        rating: _rating,
        description: _descriptionController.text.trim().isNotEmpty
            ? _descriptionController.text.trim()
            : null,
        publishedDate: _publishedDate,
        genres: _genres.isNotEmpty ? _genres : null,
        updatedAt: DateTime.now(),
      );

      await firestoreService.updateItem(updatedItem);

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Item atualizado com sucesso!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Aplicar tema claro para os campos de entrada
    return Theme(
      data: ThemeData(
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white, // Fundo branco para contraste
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.grey),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
              color: Color(0xFF8D6E63),
              width: 2,
            ), // Antique Brown
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.grey),
          ),
          labelStyle: const TextStyle(color: Color(0xFF3E2723)), // Dark Brown
          hintStyle: TextStyle(
            color: Color(0xFF8D6E63).withOpacity(0.7),
          ), // Antique Brown claro
        ),
        scaffoldBackgroundColor: const Color(
          0xFFFFFBF7,
        ), // Warm Cream para fundo
      ),
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFF8D6E63), // Antique Brown
          foregroundColor: Colors.white,
          title: const Text('Editar Item'),
          leading: IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            TextButton(
              onPressed: _isLoading ? null : _updateItem,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text('Salvar', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildMetadataHeader(widget.item.imageUrl),

                const SizedBox(height: 12),

                if (_publishedDate != null && _publishedDate!.trim().isNotEmpty)
                  _buildInfoRow(Icons.event, 'Publicação: $_publishedDate'),

                if (_genres.isNotEmpty)
                  _buildInfoRow(
                    Icons.category,
                    'Gêneros: ${_genres.join(' • ')}',
                  ),

                if (_descriptionController.text.trim().isNotEmpty)
                  _buildDescriptionBlock(_descriptionController.text.trim()),

                const SizedBox(height: 24),

                // Tipo
                DropdownButtonFormField<ItemType>(
                  value: _selectedType,
                  decoration: const InputDecoration(labelText: 'Tipo *'),
                  items: const [
                    DropdownMenuItem(
                      value: ItemType.manga,
                      child: Text('Mangá'),
                    ),
                    DropdownMenuItem(
                      value: ItemType.book,
                      child: Text('Livro'),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedType = value!;
                    });
                  },
                ),

                const SizedBox(height: 16),

                // Status
                DropdownButtonFormField<ReadingStatus>(
                  value: _selectedStatus,
                  decoration: const InputDecoration(labelText: 'Status *'),
                  items: const [
                    DropdownMenuItem(
                      value: ReadingStatus.wantToRead,
                      child: Text('Pretendo ler'),
                    ),
                    DropdownMenuItem(
                      value: ReadingStatus.reading,
                      child: Text('Lendo'),
                    ),
                    DropdownMenuItem(
                      value: ReadingStatus.read,
                      child: Text('Lido'),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedStatus = value!;
                    });
                  },
                ),

                const SizedBox(height: 16),

                // Capítulo atual (para mangás)
                if (_selectedType == ItemType.manga)
                  TextFormField(
                    controller: _currentChapterController,
                    decoration: const InputDecoration(
                      labelText: 'Capítulo atual',
                      hintText: 'Ex: 15',
                    ),
                    keyboardType: TextInputType.number,
                  ),

                // Página atual (para livros em andamento)
                if (_selectedType == ItemType.book &&
                    _selectedStatus != ReadingStatus.read)
                  TextFormField(
                    controller: _currentPageController,
                    decoration: const InputDecoration(
                      labelText: 'Página atual',
                      hintText: 'Ex: 150',
                    ),
                    keyboardType: TextInputType.number,
                  ),

                const SizedBox(height: 16),

                // Avaliação
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Avaliação'),
                    const SizedBox(height: 8),
                    RatingBar.builder(
                      initialRating: _rating,
                      minRating: 0,
                      direction: Axis.horizontal,
                      allowHalfRating: true,
                      itemCount: 5,
                      itemSize: 40,
                      itemBuilder: (context, _) =>
                          const Icon(Icons.star, color: Colors.amber),
                      onRatingUpdate: (rating) {
                        setState(() {
                          _rating = rating;
                        });
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                const SizedBox(height: 24),

                // Mensagem de erro
                if (_errorMessage != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: Colors.red.shade700),
                      textAlign: TextAlign.center,
                    ),
                  ),

                const SizedBox(height: 16),

                // Botão atualizar
                ElevatedButton(
                  onPressed: _isLoading ? null : _updateItem,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Text(
                          'Atualizar Item',
                          style: TextStyle(fontSize: 16),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetadataHeader(String? imageUrl) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 72,
              height: 108,
              color: Colors.brown.shade50,
              child: imageUrl != null
                  ? Image.network(
                      imageUrl,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Icon(
                        Icons.menu_book,
                        color: Colors.brown.shade300,
                        size: 30,
                      ),
                    )
                  : Icon(
                      Icons.menu_book,
                      color: Colors.brown.shade300,
                      size: 30,
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _nameController.text.isNotEmpty
                      ? _nameController.text
                      : 'Sem título',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _authorController.text.isNotEmpty
                      ? _authorController.text
                      : 'Autor não informado',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: const Color(0xFF8D6E63)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14, color: Color(0xFF3E2723)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionBlock(String description) {
    final isLongDescription = description.length > 180;

    return Container(
      margin: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            description,
            maxLines: _isDescriptionExpanded ? null : 3,
            overflow: _isDescriptionExpanded
                ? TextOverflow.visible
                : TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14, height: 1.35),
          ),
          if (isLongDescription)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () {
                  setState(() {
                    _isDescriptionExpanded = !_isDescriptionExpanded;
                  });
                },
                style: TextButton.styleFrom(padding: EdgeInsets.zero),
                child: Text(_isDescriptionExpanded ? 'Ler menos' : 'Ler mais'),
              ),
            ),
        ],
      ),
    );
  }
}
