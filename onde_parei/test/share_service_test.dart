import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onde_parei/models/item_model.dart';
import 'package:onde_parei/services/share_service.dart';
import 'package:onde_parei/widgets/review_card.dart';

ItemModel _item() => ItemModel(
  id: '1',
  userId: 'u',
  name: 'Berserk',
  type: ItemType.manga,
  status: ReadingStatus.read,
  currentChapter: '364',
  currentPage: '',
  rating: 5,
  review: 'Vale cada capítulo.',
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a captura sai em 1080x1350, o 4:5 de feed', (tester) async {
    final key = GlobalKey();

    tester.view.physicalSize = const Size(
      ShareReviewCard.width,
      ShareReviewCard.height,
    );
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        // Tema cru de propósito: dentro de `runAsync` o `GoogleFonts` tenta
        // baixar a fonte de verdade e o teste morre na rede. Aqui só interessa
        // o tamanho do PNG.
        theme: ThemeData.dark(),
        home: RepaintBoundary(key: key, child: ShareReviewCard(item: _item())),
      ),
    );
    await tester.pump();

    // `toByteData` e o decode dependem do loop assíncrono real da engine —
    // fora de `runAsync` o teste simplesmente trava.
    late final ui.Image imagem;
    await tester.runAsync(() async {
      final png = await ShareService.capture(key);
      final codec = await ui.instantiateImageCodec(png);
      imagem = (await codec.getNextFrame()).image;
    });

    expect(imagem.width, 1080);
    expect(imagem.height, 1350);
  });

  test('o nome do arquivo vem do título, sem acento nem barra', () {
    expect(
      ShareService.fileNameFor('O Nome do Vento'),
      'onde-parei-o-nome-do-vento.png',
    );
    expect(
      ShareService.fileNameFor('Mushishi: Zoku Shou / 蟲師'),
      'onde-parei-mushishi-zoku-shou.png',
    );
    expect(ShareService.fileNameFor('蟲師'), 'onde-parei-review.png');
  });

  test('título muito longo não vira nome de arquivo gigante', () {
    final nome = ShareService.fileNameFor('palavra ' * 30);

    expect(nome.length, lessThanOrEqualTo('onde-parei-.png'.length + 40));
  });
}
