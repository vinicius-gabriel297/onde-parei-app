import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onde_parei/models/item_model.dart';
import 'package:onde_parei/screens/home/home_screen.dart';
import 'package:onde_parei/theme/app_theme.dart';
import 'package:onde_parei/widgets/ui_kit.dart';

ItemModel _item({
  String name = 'Um título razoavelmente comprido para testar quebra',
  ItemType type = ItemType.manhwa,
  ReadingStatus status = ReadingStatus.reading,
}) => ItemModel(
  id: '1',
  userId: 'u',
  name: name,
  type: type,
  status: status,
  currentChapter: '42',
  currentPage: '',
  totalChapters: '200',
  totalPages: '',
  rating: 4.5,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

Future<void> _pump(
  WidgetTester tester,
  Widget child,
  ThemeData Function() themeBuilder,
) async {
  final theme = themeBuilder();
  tester.view.physicalSize = const Size(375, 812);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: Scaffold(body: Center(child: child)),
    ),
  );
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Os temas são construídos dentro de cada teste: `GoogleFonts` precisa do
  // binding já inicializado para resolver o AssetManifest.
  for (final entry in <String, ThemeData Function()>{
    'tema claro': AppTheme.light,
    'tema escuro': AppTheme.dark,
  }.entries) {
    final label = entry.key;
    final theme = entry.value;

    testWidgets('$label: selos e chips renderizam sem estouro', (tester) async {
      await _pump(
        tester,
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final type in ItemType.values)
              TypeBadge(label: type.label, color: AppColors.forType(type.name)),
            for (final status in ReadingStatus.values)
              StatusPill(status: status),
            const SizedBox(
              width: 200,
              child: ReadingProgressBar(value: 0.4, color: AppColors.gold),
            ),
          ],
        ),
        theme,
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Manhwa'), findsOneWidget);
      expect(find.text('Lendo'), findsOneWidget);
    });

    testWidgets('$label: estado vazio renderiza', (tester) async {
      await _pump(
        tester,
        const EmptyState(
          icon: Icons.auto_stories_rounded,
          title: 'Estante vazia',
          message: 'Adicione o primeiro título.',
        ),
        theme,
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Estante vazia'), findsOneWidget);
    });

    testWidgets('$label: capa da estante mostra progresso', (tester) async {
      await _pump(
        tester,
        SizedBox(width: 120, height: 210, child: ShelfCoverTile(item: _item())),
        theme,
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(ReadingProgressBar), findsOneWidget);
    });

    testWidgets('$label: cabeçalho de seção com ação', (tester) async {
      await _pump(
        tester,
        SectionHeader(
          title: 'Continuar lendo',
          subtitle: '3 leituras em andamento',
          action: TextButton(onPressed: () {}, child: const Text('Ver tudo')),
        ),
        theme,
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Continuar lendo'), findsOneWidget);
    });
  }

  testWidgets('capa sem imagem cai no fallback tipográfico', (tester) async {
    await _pump(
      tester,
      const SizedBox(
        width: 90,
        height: 130,
        child: CoverArt(imageUrl: null, title: 'Sem capa'),
      ),
      AppTheme.dark,
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Sem capa'), findsOneWidget);
  });
}
