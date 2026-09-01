import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onde_parei/models/item_model.dart';
import 'package:onde_parei/theme/app_theme.dart';
import 'package:onde_parei/widgets/review_card.dart';

ItemModel _item({
  String name = 'Berserk',
  String? author = 'Kentaro Miura',
  String? imageUrl,
  ReadingStatus status = ReadingStatus.read,
  double rating = 4.5,
  String review = 'Sombrio do começo ao fim, e vale cada página.',
}) => ItemModel(
  id: '1',
  userId: 'u',
  name: name,
  author: author,
  imageUrl: imageUrl,
  type: ItemType.manga,
  status: status,
  currentChapter: '364',
  currentPage: '',
  rating: rating,
  review: review,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

/// O card tem medidas fixas, então a tela do teste precisa comportá-lo inteiro
/// — senão qualquer estouro vira erro de layout em vez de erro de conteúdo.
Future<void> _pump(
  WidgetTester tester,
  ItemModel item,
  ThemeData Function() themeBuilder,
) async {
  tester.view.physicalSize = const Size(
    ShareReviewCard.width,
    ShareReviewCard.height,
  );
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: themeBuilder(),
      home: Scaffold(body: ShareReviewCard(item: item)),
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
    testWidgets('${entry.key}: mostra título, autor, nota e review', (
      tester,
    ) async {
      await _pump(tester, _item(), entry.value);

      // Sem `coverUrl` a capa cai no fallback tipográfico, que também escreve
      // o título — por isso o texto aparece duas vezes.
      expect(find.text('Berserk'), findsNWidgets(2));
      expect(find.text('Kentaro Miura'), findsOneWidget);
      expect(find.text('4.5'), findsOneWidget);
      expect(
        find.textContaining('Sombrio do começo ao fim'),
        findsOneWidget,
      );
      expect(find.text('Mangá'), findsOneWidget);
      expect(find.text('Lido'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('sem review e sem nota ainda renderiza o card', (tester) async {
    await _pump(
      tester,
      _item(review: '', rating: 0, author: null),
      AppTheme.dark,
    );

    expect(find.text('Berserk'), findsNWidgets(2));
    expect(find.text('0.0'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('review longo é cortado em vez de estourar o card', (
    tester,
  ) async {
    await _pump(tester, _item(review: 'Muito bom. ' * 120), AppTheme.dark);

    expect(tester.takeException(), isNull);
  });

  testWidgets('abandonado mostra o status correspondente', (tester) async {
    await _pump(tester, _item(status: ReadingStatus.dropped), AppTheme.dark);

    expect(find.text('Abandonei'), findsOneWidget);
  });

  testWidgets('a escala de fonte do sistema não muda o layout do card', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(
      ShareReviewCard.width,
      ShareReviewCard.height,
    );
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2.4)),
          child: Scaffold(body: ShareReviewCard(item: _item())),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}
