import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:share_plus/share_plus.dart';

import 'file_download.dart';

/// Como o card saiu do app.
enum ShareOutcome {
  /// Foi para a folha de compartilhamento do sistema.
  shared,

  /// O navegador não aceita compartilhar arquivo — o PNG foi baixado.
  downloaded,

  /// Nem uma coisa nem outra (desktop sem folha e sem navegador).
  unavailable,
}

/// Transforma o card em PNG e o entrega ao usuário.
abstract final class ShareService {
  /// Captura o que está sob o [RepaintBoundary] apontado por [boundaryKey].
  ///
  /// `pixelRatio` 2 sobre o card de 540x675 dá 1080x1350 — a proporção 4:5 de
  /// feed. Não use o pixel ratio da tela: a imagem tem que sair igual em
  /// qualquer aparelho.
  static Future<Uint8List> capture(
    GlobalKey boundaryKey, {
    double pixelRatio = 2,
  }) async {
    final boundary =
        boundaryKey.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;
    if (boundary == null) {
      throw Exception('O card ainda não está pronto para virar imagem.');
    }

    final image = await boundary.toImage(pixelRatio: pixelRatio);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) throw Exception('Não foi possível gerar a imagem.');
      return data.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  }

  /// Nome de arquivo derivado do título, sem acento nem separador de caminho.
  static String fileNameFor(String title) {
    final slug = title
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    final base = slug.isEmpty ? 'review' : slug;
    return 'onde-parei-${base.substring(0, base.length.clamp(0, 40))}.png';
  }

  /// Abre a folha de compartilhamento com o PNG.
  ///
  /// No Web só o Chrome mobile compartilha arquivo; no desktop a Web Share API
  /// recusa. Isso não é erro — é o caminho normal daquele ambiente, e o
  /// download cobre o caso, igual ao que a exportação já faz.
  static Future<ShareOutcome> shareImage({
    required Uint8List bytes,
    required String fileName,
    required String text,
    Rect? sharePositionOrigin,
  }) async {
    try {
      final result = await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(bytes, mimeType: 'image/png', name: fileName),
          ],
          fileNameOverrides: [fileName],
          text: text,
          sharePositionOrigin: sharePositionOrigin,
        ),
      );
      if (result.status != ShareResultStatus.unavailable) {
        return ShareOutcome.shared;
      }
    } catch (_) {
      // Cai para o download logo abaixo.
    }

    return await saveImage(bytes: bytes, fileName: fileName)
        ? ShareOutcome.downloaded
        : ShareOutcome.unavailable;
  }

  /// Salva o PNG direto, sem passar pela folha de compartilhamento.
  static Future<bool> saveImage({
    required Uint8List bytes,
    required String fileName,
  }) {
    return downloadBytesFile(fileName, bytes, 'image/png');
  }
}
