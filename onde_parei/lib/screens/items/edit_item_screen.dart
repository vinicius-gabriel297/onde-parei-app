import 'package:flutter/material.dart';

import '../../models/item_model.dart';
import 'item_form.dart';

/// Tela de edição — delega para o formulário compartilhado.
class EditItemScreen extends StatelessWidget {
  final ItemModel item;

  const EditItemScreen({super.key, required this.item});

  @override
  Widget build(BuildContext context) => ItemFormScreen(item: item);
}
