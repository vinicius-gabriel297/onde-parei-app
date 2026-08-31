/// Fora do navegador não há um destino óbvio para salvar sem dependências
/// nativas de sistema de arquivos. A tela de exportação trata `false`
/// oferecendo a cópia do conteúdo.
Future<bool> downloadTextFile(
  String fileName,
  String content,
  String mimeType,
) async =>
    false;
