import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:provider/provider.dart';

import '../../models/api_models.dart';
import '../../models/item_model.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ui_kit.dart';

/// Formulário compartilhado por "adicionar" e "editar". Antes as duas telas
/// eram cópias quase idênticas uma da outra.
class ItemFormScreen extends StatefulWidget {
  /// Item existente (modo edição).
  final ItemModel? item;

  /// Resultado de busca (modo criação).
  final SearchResult? searchResult;

  const ItemFormScreen({super.key, this.item, this.searchResult});

  bool get isEditing => item != null;

  @override
  State<ItemFormScreen> createState() => _ItemFormScreenState();
}

class _ItemFormScreenState extends State<ItemFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _authorController;
  late final TextEditingController _currentController;
  late final TextEditingController _totalController;

  late ItemType _type;
  late ReadingStatus _status;
  late double _rating;

  String? _imageUrl;
  String? _description;
  String? _publishedDate;
  List<String> _genres = const [];

  bool _isSaving = false;
  bool _descriptionExpanded = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    final item = widget.item;
    final result = widget.searchResult;

    _nameController = TextEditingController(
      text: item?.name ?? result?.title ?? '',
    );
    _authorController = TextEditingController(
      text: item?.author ?? result?.authors?.firstOrNull ?? '',
    );

    _type = item?.type ?? ItemTypeX.fromSearchType(result?.type ?? 'book');
    _status = item?.status ?? ReadingStatus.wantToRead;
    _rating = item?.rating ?? 0;

    _imageUrl = item?.imageUrl ?? result?.imageUrl;
    _description = item?.description ?? result?.description;
    _publishedDate = item?.publishedDate ?? result?.year;

    final rawGenres = item?.genres ?? result?.genres;
    _genres = (rawGenres ?? const []).take(5).toList();

    _currentController = TextEditingController(
      text: item == null
          ? ''
          : (item.type.countsChapters ? item.currentChapter : item.currentPage),
    );
    _totalController = TextEditingController(
      text: item != null
          ? (item.type.countsChapters ? item.totalChapters : item.totalPages)
          : (result?.totalUnits != null && result!.totalUnits! > 0
                ? '${result.totalUnits}'
                : ''),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _authorController.dispose();
    _currentController.dispose();
    _totalController.dispose();
    super.dispose();
  }

  double? get _progressPreview {
    if (_status == ReadingStatus.read) return 1;
    final current = int.tryParse(_currentController.text.trim());
    final total = int.tryParse(_totalController.text.trim());
    if (current == null || total == null || total <= 0) return null;
    return (current / total).clamp(0.0, 1.0);
  }

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'O título é obrigatório.');
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    final navigator = Navigator.of(context);
    final auth = context.read<AuthService>();
    final firestore = context.read<FirestoreService>();

    try {
      final user = auth.currentUser;
      if (user == null) throw Exception('Usuário não autenticado.');

      final current = _currentController.text.trim();
      final total = _totalController.text.trim();
      final countsChapters = _type.countsChapters;

      final base =
          widget.item ??
          ItemModel(
            id: '',
            userId: user.uid,
            name: '',
            type: _type,
            status: _status,
            currentChapter: '',
            currentPage: '',
            rating: 0,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );

      final item = base.copyWith(
        userId: user.uid,
        name: _nameController.text.trim(),
        author: _authorController.text.trim().isEmpty
            ? null
            : _authorController.text.trim(),
        imageUrl: _imageUrl,
        description: _description,
        publishedDate: _publishedDate,
        genres: _genres.isEmpty ? null : _genres,
        type: _type,
        status: _status,
        currentChapter: countsChapters ? current : base.currentChapter,
        currentPage: countsChapters ? base.currentPage : current,
        totalChapters: countsChapters ? total : base.totalChapters,
        totalPages: countsChapters ? base.totalPages : total,
        rating: _rating,
        updatedAt: DateTime.now(),
      );

      if (widget.isEditing) {
        await firestore.updateItem(item);
      } else {
        await firestore.addItem(item);
        final result = widget.searchResult;
        if (result != null) {
          // Alimenta o catálogo compartilhado: a próxima busca por este
          // título responde direto do Firestore.
          firestore.upsertBookToCatalog(result, user.uid).ignore();
        }
      }

      if (!mounted) return;
      navigator.pop();
      AppSnack.show(
        context,
        widget.isEditing
            ? 'Alterações salvas.'
            : '"${item.name}" foi para a estante.',
        icon: Icons.bookmark_added_rounded,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = '$e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _delete() async {
    final item = widget.item;
    if (item == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remover da estante'),
        content: Text('Deseja remover "${item.name}"?'),
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

    if (confirmed != true || !mounted) return;

    final navigator = Navigator.of(context);
    try {
      await context.read<FirestoreService>().deleteItem(item.id);
      if (!mounted) return;
      navigator.pop();
      AppSnack.show(
        context,
        'Removido da estante.',
        icon: Icons.delete_outline_rounded,
      );
    } catch (e) {
      if (mounted) AppSnack.error(context, '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final description = (_description ?? '').trim();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
          tooltip: 'Fechar',
        ),
        title: Text(widget.isEditing ? 'Editar título' : 'Adicionar à estante'),
        actions: [
          if (widget.isEditing)
            IconButton(
              tooltip: 'Remover',
              onPressed: _isSaving ? null : _delete,
              icon: Icon(
                Icons.delete_outline_rounded,
                color: scheme.error,
              ),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
          children: [
            _Header(
              imageUrl: _imageUrl,
              title: _nameController.text,
              author: _authorController.text,
              type: _type,
              publishedDate: _publishedDate,
            ),

            if (_genres.isNotEmpty) ...[
              const SizedBox(height: 16),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final genre in _genres)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        border: Border.all(color: scheme.outlineVariant),
                      ),
                      child: Text(genre, style: theme.textTheme.labelSmall),
                    ),
                ],
              ),
            ],

            if (description.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                description,
                maxLines: _descriptionExpanded ? null : 4,
                overflow: _descriptionExpanded
                    ? TextOverflow.visible
                    : TextOverflow.ellipsis,
                style: theme.textTheme.bodyLarge,
              ),
              if (description.length > 200)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    style: TextButton.styleFrom(padding: EdgeInsets.zero),
                    onPressed: () => setState(
                      () => _descriptionExpanded = !_descriptionExpanded,
                    ),
                    child: Text(
                      _descriptionExpanded ? 'Ler menos' : 'Ler mais',
                    ),
                  ),
                ),
            ],

            const SizedBox(height: 24),
            Text('Status', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            _StatusSelector(
              status: _status,
              onChanged: (value) => setState(() => _status = value),
            ),

            const SizedBox(height: 20),
            Text('Detalhes', style: theme.textTheme.titleSmall),
            const SizedBox(height: 10),

            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Título'),
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) => setState(() {}),
              validator: (value) => (value ?? '').trim().isEmpty
                  ? 'Informe o título'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _authorController,
              decoration: const InputDecoration(labelText: 'Autor'),
              textCapitalization: TextCapitalization.words,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<ItemType>(
              value: _type,
              decoration: const InputDecoration(labelText: 'Tipo'),
              items: [
                for (final type in ItemType.values)
                  DropdownMenuItem(value: type, child: Text(type.label)),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() => _type = value);
              },
            ),

            const SizedBox(height: 22),
            Text(
              _type.countsChapters ? 'Progresso (capítulos)' : 'Progresso (páginas)',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _currentController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: _type.countsChapters
                          ? 'Capítulo atual'
                          : 'Página atual',
                      hintText: 'Ex: 15',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _totalController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: 'Total',
                      hintText: _type.countsChapters ? 'Ex: 120' : 'Ex: 380',
                    ),
                  ),
                ),
              ],
            ),
            if (_progressPreview != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ReadingProgressBar(
                      value: _progressPreview!,
                      color: StatusPill.colorOf(_status),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${(_progressPreview! * 100).round()}%',
                    style: theme.textTheme.labelMedium,
                  ),
                ],
              ),
            ],

            const SizedBox(height: 22),
            Text('Sua nota', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Row(
              children: [
                RatingBar.builder(
                  initialRating: _rating,
                  minRating: 0,
                  allowHalfRating: true,
                  itemCount: 5,
                  itemSize: 32,
                  glow: false,
                  unratedColor: scheme.outlineVariant,
                  itemPadding: const EdgeInsets.only(right: 4),
                  itemBuilder: (_, __) => const Icon(
                    Icons.star_rounded,
                    color: AppColors.gold,
                  ),
                  onRatingUpdate: (value) => setState(() => _rating = value),
                ),
                const SizedBox(width: 10),
                if (_rating > 0)
                  TextButton(
                    onPressed: () => setState(() => _rating = 0),
                    child: const Text('Limpar'),
                  ),
              ],
            ),

            if (_errorMessage != null) ...[
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(
                    color: scheme.error.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      size: 18,
                      color: scheme.error,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: SizedBox(
          height: 52,
          child: FilledButton.icon(
            onPressed: _isSaving ? null : _save,
            icon: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check_rounded, size: 19),
            label: Text(
              widget.isEditing ? 'Salvar alterações' : 'Guardar na estante',
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Cabeçalho ────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final String? imageUrl;
  final String title;
  final String author;
  final ItemType type;
  final String? publishedDate;

  const _Header({
    required this.imageUrl,
    required this.title,
    required this.author,
    required this.type,
    required this.publishedDate,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CoverArt(
          imageUrl: imageUrl,
          title: title.isEmpty ? 'Sem título' : title,
          width: 96,
          height: 144,
          decodeWidth: 220,
          radius: AppRadius.md,
          fallbackIcon: type.isBook
              ? Icons.menu_book_rounded
              : Icons.import_contacts_rounded,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title.isEmpty ? 'Sem título' : title,
                style: theme.textTheme.titleLarge,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Text(
                author.isEmpty ? 'Autor não informado' : author,
                style: theme.textTheme.bodyMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  TypeBadge(
                    label: type.label,
                    color: AppColors.forType(type.name),
                  ),
                  if ((publishedDate ?? '').isNotEmpty)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.event_rounded, size: 13),
                        const SizedBox(width: 4),
                        Text(
                          publishedDate!,
                          style: theme.textTheme.labelSmall,
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Seletor de status ────────────────────────────────────────────────────────

class _StatusSelector extends StatelessWidget {
  final ReadingStatus status;
  final ValueChanged<ReadingStatus> onChanged;

  const _StatusSelector({required this.status, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final option in ReadingStatus.values) ...[
          Expanded(
            child: _StatusOption(
              status: option,
              selected: status == option,
              onTap: () => onChanged(option),
            ),
          ),
          if (option != ReadingStatus.values.last) const SizedBox(width: 8),
        ],
      ],
    );
  }
}

class _StatusOption extends StatelessWidget {
  final ReadingStatus status;
  final bool selected;
  final VoidCallback onTap;

  const _StatusOption({
    required this.status,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = StatusPill.colorOf(status);

    return Material(
      color: selected ? color.withValues(alpha: 0.16) : scheme.surfaceContainer,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: selected ? color : scheme.outlineVariant,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(
                StatusPill.iconOf(status),
                size: 19,
                color: selected ? color : scheme.onSurfaceVariant,
              ),
              const SizedBox(height: 6),
              Text(
                status.label,
                textAlign: TextAlign.center,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: selected ? color : scheme.onSurfaceVariant,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
