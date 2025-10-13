import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../models/item_model.dart';

class EditItemScreen extends StatefulWidget {
  final ItemModel item;

  const EditItemScreen({
    super.key,
    required this.item,
  });

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

  @override
  void initState() {
    super.initState();
    // Inicializar controllers com os dados do item
    _nameController = TextEditingController(text: widget.item.name);
    _authorController = TextEditingController(text: widget.item.author ?? '');
    _descriptionController = TextEditingController(text: widget.item.description ?? '');
    _currentChapterController = TextEditingController(text: widget.item.currentChapter);
    _currentPageController = TextEditingController(text: widget.item.currentPage);

    _selectedType = widget.item.type;
    _selectedStatus = widget.item.status;
    _rating = widget.item.rating;
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
      final firestoreService = Provider.of<FirestoreService>(context, listen: false);

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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar Item'),
        leading: IconButton(
          icon: const Icon(Icons.close),
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
                : const Text('Salvar'),
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
              if (widget.item.imageUrl != null)
                Container(
                  height: 200,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    image: DecorationImage(
                      image: NetworkImage(widget.item.imageUrl!),
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
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
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
    );
  }
}
