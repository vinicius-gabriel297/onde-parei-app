import 'package:flutter/material.dart';

import '../../models/api_models.dart';
import 'item_form.dart';

/// Tela de criação — delega para o formulário compartilhado.
class AddItemScreen extends StatelessWidget {
  final SearchResult? searchResult;

  const AddItemScreen({super.key, this.searchResult});

  @override
  Widget build(BuildContext context) =>
      ItemFormScreen(searchResult: searchResult);
}
