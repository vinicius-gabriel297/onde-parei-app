import 'dart:typed_data';

/// Fora do navegador não há um destino óbvio para salvar sem dependências
/// nativas de sistema de arquivos. A tela de exportação trata `false`
/// oferecendo a cópia do conteúdo.
Future<bool> downloadTextFile(
  String fileName,
  String content,
  String mimeType,
) async =>
    false;

/// Mesma limitação para os bytes do PNG do card de compartilhamento. Fora do
/// navegador quem entrega o arquivo é a folha de compartilhamento nativa.
Future<bool> downloadBytesFile(
  String fileName,
  Uint8List bytes,
  String mimeType,
) async =>
    false;
