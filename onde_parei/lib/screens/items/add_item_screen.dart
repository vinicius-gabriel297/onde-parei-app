import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../models/item_model.dart';
import '../../models/api_models.dart';

class AddItemScreen extends StatefulWidget {
  final SearchResult? searchResult;

  const AddItemScreen({
    super.key,
    this.searchResult,
  });

  @override
  State<AddItemScreen> createState() => _AddItemScreenState();
}

class _AddItemScreenState extends State<AddItemScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _authorController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _currentChapterController = TextEditingController();
  final _currentPageController = TextEditingController();

  ItemType _selectedType = ItemType.manga;
  ReadingStatus _selectedStatus = ReadingStatus.wantToRead;
  double _rating = 0.0;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.searchResult != null) {
      _nameController.text = widget.searchResult!.title;
      if (widget.searchResult!.authors != null && widget.searchResult!.authors!.isNotEmpty) {
        _authorController.text = widget.searchResult!.authors!.first;
      }
      if (widget.searchResult!.description != null) {
        _descriptionController.text = widget.searchResult!.description!;
      }
      _selectedType = widget.searchResult!.type == 'manga' ? ItemType.manga : ItemType.book;
    }
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

  Future<void> _saveItem() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final firestoreService = Provider.of<FirestoreService>(context, listen: false);

      final user = authService.currentUser;
      if (user == null) {
        throw Exception('Usuário não autenticado');
      }

      final item = ItemModel(
        id: '', // Será gerado pelo Firestore
        userId: user.uid,
        name: _nameController.text.trim(),
        imageUrl: widget.searchResult?.imageUrl,
        type: _selectedType,
        status: _selectedStatus,
        currentChapter: _currentChapterController.text.trim(),
        currentPage: _currentPageController.text.trim(),
        rating: _rating,
        description: _descriptionController.text.trim().isNotEmpty
            ? _descriptionController.text.trim()
            : null,
        author: _authorController.text.trim().isNotEmpty
            ? _authorController.text.trim()
            : null,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await firestoreService.addItem(item);

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Item adicionado com sucesso!'),
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
            borderSide: const BorderSide(color: Color(0xFF8D6E63), width: 2), // Antique Brown
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.grey),
          ),
          labelStyle: const TextStyle(color: Color(0xFF3E2723)), // Dark Brown
          hintStyle: TextStyle(color: Color(0xFF8D6E63).withOpacity(0.7)), // Antique Brown claro
        ),
        scaffoldBackgroundColor: const Color(0xFFFFFBF7), // Warm Cream para fundo
      ),
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFF8D6E63), // Antique Brown
          foregroundColor: Colors.white,
          title: const Text('Adicionar Item'),
          leading: IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            TextButton(
              onPressed: _isLoading ? null : _saveItem,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      'Salvar',
                      style: TextStyle(color: Colors.white),
                    ),
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
                // Imagem (se disponível)
                if (widget.searchResult?.imageUrl != null)
                  Container(
                    height: 200,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      image: DecorationImage(
                        image: NetworkImage(widget.searchResult!.imageUrl!),
                        fit: BoxFit.cover,
                        onError: (exception, stackTrace) {
                          // Imagem não carregou, será tratada abaixo
                        },
                      ),
                    ),
                  ),

                const SizedBox(height: 24),

                // Nome
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nome *',
                    hintText: 'Nome do mangá ou livro',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Campo obrigatório';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // Autor
                TextFormField(
                  controller: _authorController,
                  decoration: const InputDecoration(
                    labelText: 'Autor',
                    hintText: 'Nome do autor ou autores',
                  ),
                ),

                const SizedBox(height: 16),

                // Tipo
                DropdownButtonFormField<ItemType>(
                  value: _selectedType,
                  decoration: const InputDecoration(
                    labelText: 'Tipo *',
                  ),
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
                  decoration: const InputDecoration(
                    labelText: 'Status *',
                  ),
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

                // Página atual (para livros)
                if (_selectedType == ItemType.book)
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
                      itemBuilder: (context, _) => const Icon(
                        Icons.star,
                        color: Colors.amber,
                      ),
                      onRatingUpdate: (rating) {
                        setState(() {
                          _rating = rating;
                        });
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Descrição
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Descrição',
                    hintText: 'Sinopse ou observações pessoais',
                  ),
                  maxLines: 3,
                ),

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

                // Botão salvar
                ElevatedButton(
                  onPressed: _isLoading ? null : _saveItem,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Salvar Item',
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
}
