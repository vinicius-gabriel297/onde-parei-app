import 'dart:convert';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Entrega o arquivo pelo próprio navegador: monta um Blob, cria um link
/// temporário e dispara o clique. Não sobe nada para servidor nenhum.
Future<bool> downloadTextFile(
  String fileName,
  String content,
  String mimeType,
) async {
  // Codifica em UTF-8 antes do Blob: com a string crua o navegador reinterpreta
  // os acentos como latin-1.
  final bytes = utf8.encode(content).toJS;
  final blob = web.Blob(
    <JSUint8Array>[bytes].toJS,
    web.BlobPropertyBag(type: mimeType),
  );

  final url = web.URL.createObjectURL(blob);
  final anchor = web.document.createElement('a') as web.HTMLAnchorElement
    ..href = url
    ..download = fileName
    ..style.display = 'none';

  web.document.body?.appendChild(anchor);
  anchor.click();
  anchor.remove();
  web.URL.revokeObjectURL(url);

  return true;
}
