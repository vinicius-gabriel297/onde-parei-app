import 'package:flutter/material.dart';

import '../items/item_list_screen.dart';
import '../search/search_screen.dart';
import '../settings/settings_screen.dart';
import 'home_screen.dart';

/// Casca com navegação por abas. Usa [IndexedStack] para preservar o estado
/// de cada aba — trocar de aba fica instantâneo e a busca não é refeita.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  static HomeShellState? of(BuildContext context) =>
      context.findAncestorStateOfType<HomeShellState>();

  @override
  State<HomeShell> createState() => HomeShellState();
}

class HomeShellState extends State<HomeShell> {
  int _index = 0;

  void goToTab(int index) {
    if (_index == index) return;
    setState(() => _index = index);
  }

  void openSearch() => goToTab(2);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [
          HomeScreen(),
          ItemListScreen(),
          SearchScreen(),
          SettingsScreen(),
        ],
      ),
      floatingActionButton: _index == 2
          ? null
          : FloatingActionButton.extended(
              onPressed: openSearch,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Adicionar'),
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: goToTab,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Início',
          ),
          NavigationDestination(
            icon: Icon(Icons.library_books_outlined),
            selectedIcon: Icon(Icons.library_books_rounded),
            label: 'Estante',
          ),
          NavigationDestination(
            icon: Icon(Icons.search_rounded),
            selectedIcon: Icon(Icons.saved_search_rounded),
            label: 'Explorar',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}
