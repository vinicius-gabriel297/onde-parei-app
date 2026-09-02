import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onde_parei/models/item_model.dart';
import 'package:onde_parei/services/recap_service.dart';
import 'package:onde_parei/theme/app_theme.dart';
import 'package:onde_parei/widgets/recap_card.dart';

ItemModel _item({
  required String name,
  ItemType type = ItemType.book,
  double rating = 0,
  String totalPages = '',
  List<String>? genres,
  required DateTime finishedAt,
  DateTime? startedAt,
}) => ItemModel(
  id: name,
  userId: 'u',
  name: name,
  author: 'Autor',
  type: type,
  status: ReadingStatus.read,
  currentChapter: '',
  currentPage: '',
  totalPages: totalPages,
  rating: rating,
  genres: genres,
  startedAt: startedAt,
  finishedAt: finishedAt,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

ReadingRecap _recap({List<ItemModel>? items}) => ReadingRecap.forYear(
  items ??
      [
        _item(
          name: 'Duna',
          rating: 5,
          totalPages: '600',
          genres: const ['Ficção científica'],
          startedAt: DateTime(2026, 1, 2),
          finishedAt: DateTime(2026, 1, 12),
        ),
        _item(
          name: 'Berserk',
          type: ItemType.manga,
          rating: 4,
          genres: const ['Aventura'],
          finishedAt: DateTime(2026, 6, 3),
        ),
      ],
  2026,
);

/// O card tem medidas fixas: a tela do teste precisa comportá-lo inteiro, senão
/// um estouro de layout vira erro de conteúdo.
Future<void> _pump(
  WidgetTester tester,
  ReadingRecap recap,
  ThemeData Function() themeBuilder, {
  String readerName = '',
  TextScaler? textScaler,
}) async {
  tester.view.physicalSize = const Size(RecapCard.width, RecapCard.height);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final card = RecapCard(recap: recap, readerName: readerName);

  await tester.pumpWidget(
    MaterialApp(
      theme: themeBuilder(),
      home: textScaler == null
          ? Scaffold(body: card)
          : MediaQuery(
              data: MediaQueryData(textScaler: textScaler),
              child: Scaffold(body: card),
            ),
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
    testWidgets('${entry.key}: mostra total, favorita e gêneros', (
      tester,
    ) async {
      await _pump(tester, _recap(), entry.value);

      expect(find.text('2'), findsOneWidget);
      expect(find.text('obras terminadas em 2026'), findsOneWidget);
      // Sem `favoriteCoverUrl` a capa cai no fallback tipográfico, que também
      // escreve o título — por isso o texto aparece duas vezes.
      expect(find.text('Duna'), findsNWidgets(2));
      expect(find.text('Ficção científica · 1'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('o nome do leitor entra no topo quando existe', (tester) async {
    await _pump(tester, _recap(), AppTheme.dark, readerName: 'Vinicius');

    expect(find.text('A retrospectiva de Vinicius'), findsOneWidget);
  });

  testWidgets('sem nome, o topo vira o rótulo do ano', (tester) async {
    await _pump(tester, _recap(), AppTheme.dark);

    expect(find.text('Retrospectiva 2026'), findsOneWidget);
  });

  testWidgets('ano vazio ainda renderiza o card', (tester) async {
    await _pump(tester, _recap(items: const []), AppTheme.dark);

    expect(find.text('obras terminadas em 2026'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ano cheio de obras não estoura o card', (tester) async {
    final items = [
      for (var i = 0; i < 40; i++)
        _item(
          name: 'Uma obra de título bem comprido número $i',
          rating: 5 - (i % 5) * 0.5,
          totalPages: '${300 + i}',
          genres: const ['Fantasia épica e sombria', 'Aventura', 'Drama'],
          finishedAt: DateTime(2026, (i % 12) + 1, 10),
        ),
    ];

    await _pump(tester, _recap(items: items), AppTheme.dark);

    expect(tester.takeException(), isNull);
  });

  testWidgets('a escala de fonte do sistema não muda o layout do card', (
    tester,
  ) async {
    await _pump(
      tester,
      _recap(),
      AppTheme.dark,
      textScaler: const TextScaler.linear(2.4),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('a cápsula mensal troca o gráfico pelos títulos do mês', (
    tester,
  ) async {
    final recap = ReadingRecap.forMonth([
      _item(name: 'Duna', rating: 5, finishedAt: DateTime(2026, 9, 10)),
      _item(name: 'Noites brancas', rating: 4, finishedAt: DateTime(2026, 9, 20)),
    ], 2026, 9);

    await _pump(tester, recap, AppTheme.dark);

    expect(find.text('Cápsula de setembro de 2026'), findsOneWidget);
    expect(find.text('obras terminadas em setembro de 2026'), findsOneWidget);
    // No recorte mensal o rótulo do gráfico anual não existe.
    expect(find.text('Jan'), findsNothing);
    expect(find.text('Noites brancas'), findsOneWidget);
    expect(find.text('A MELHOR DO MÊS'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mês com muitos títulos resume o resto em uma linha', (
    tester,
  ) async {
    final recap = ReadingRecap.forMonth([
      for (var i = 0; i < 7; i++)
        _item(
          name: 'Obra de título bastante comprido número $i',
          rating: 4,
          finishedAt: DateTime(2026, 9, i + 1),
        ),
    ], 2026, 9);

    await _pump(tester, recap, AppTheme.dark);

    expect(find.text('e mais 4'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
