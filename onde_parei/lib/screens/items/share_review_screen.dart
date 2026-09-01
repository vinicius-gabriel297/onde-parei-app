import 'package:flutter/material.dart';

import '../../models/item_model.dart';
import '../../services/share_service.dart';
import '../../widgets/adaptive_network_image.dart';
import '../../widgets/review_card.dart';
import '../../widgets/ui_kit.dart';

/// Prévia do card de compartilhamento. O que aparece na tela é exatamente o
/// que vira PNG — o `RepaintBoundary` embrulha o mesmo widget.
class ShareReviewScreen extends StatefulWidget {
  final ItemModel item;

  const ShareReviewScreen({super.key, required this.item});

  @override
  State<ShareReviewScreen> createState() => _ShareReviewScreenState();
}

class _ShareReviewScreenState extends State<ShareReviewScreen> {
  final GlobalKey _cardKey = GlobalKey();
  final GlobalKey _shareButtonKey = GlobalKey();

  bool _resolvingCover = true;
  bool _busy = false;
  String? _coverUrl;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_resolvingCover) _resolveCover();
  }

  /// Deixa a capa em cache **antes** de liberar a captura.
  ///
  /// Duas razões: uma imagem que ainda não chegou sai em branco no PNG; e no
  /// Web a captura só enxerga imagem servida com CORS — por isso percorremos a
  /// mesma lista de candidatas do `AdaptiveNetworkImage`, em que o proxy é
  /// justamente quem garante o CORS. Nenhuma carregou: o card usa o fallback
  /// tipográfico, que é sempre capturável.
  Future<void> _resolveCover() async {
    final url = widget.item.imageUrl;
    if (url != null && url.trim().isNotEmpty) {
      for (final candidate in AdaptiveNetworkImage.candidateUrls(url)) {
        try {
          await precacheImage(NetworkImage(candidate), context);
          if (!mounted) return;
          _coverUrl = candidate;
          break;
        } catch (_) {
          // Tenta a próxima candidata.
        }
      }
    }
    if (!mounted) return;
    setState(() => _resolvingCover = false);
  }

  String get _shareText {
    final item = widget.item;
    final nota = item.rating > 0
        ? ' — ${item.rating.toStringAsFixed(1)}/5'
        : '';
    return '${item.name}$nota • ${item.status.label} no Onde Parei? '
        'https://onde-parei-ea32c.web.app';
  }

  Future<void> _run(Future<ShareOutcome> Function() action) async {
    setState(() => _busy = true);
    try {
      final outcome = await action();
      if (!mounted) return;
      switch (outcome) {
        case ShareOutcome.shared:
          break;
        case ShareOutcome.downloaded:
          AppSnack.show(
            context,
            'Imagem salva. É só anexar onde quiser postar.',
            icon: Icons.download_done_rounded,
          );
          break;
        case ShareOutcome.unavailable:
          AppSnack.error(
            context,
            'Este aparelho não conseguiu entregar a imagem.',
          );
          break;
      }
    } catch (e) {
      if (mounted) AppSnack.error(context, '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _share() {
    return _run(() async {
      final bytes = await ShareService.capture(_cardKey);
      final box =
          _shareButtonKey.currentContext?.findRenderObject() as RenderBox?;
      return ShareService.shareImage(
        bytes: bytes,
        fileName: ShareService.fileNameFor(widget.item.name),
        text: _shareText,
        // O iPad ancora a folha de compartilhamento num ponto da tela.
        sharePositionOrigin: box == null
            ? null
            : box.localToGlobal(Offset.zero) & box.size,
      );
    });
  }

  Future<void> _save() {
    return _run(() async {
      final bytes = await ShareService.capture(_cardKey);
      final saved = await ShareService.saveImage(
        bytes: bytes,
        fileName: ShareService.fileNameFor(widget.item.name),
      );
      return saved ? ShareOutcome.downloaded : ShareOutcome.unavailable;
    });
  }

  @override
  Widget build(BuildContext context) {
    final ready = !_resolvingCover && !_busy;

    return Scaffold(
      appBar: AppBar(title: const Text('Compartilhar')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: FittedBox(
                    child: RepaintBoundary(
                      key: _cardKey,
                      child: ShareReviewCard(
                        item: widget.item,
                        coverUrl: _coverUrl,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _resolvingCover
                        ? 'Preparando a capa…'
                        : 'A imagem sai em 1080x1350, pronta para o feed.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: ready ? _save : null,
                          icon: const Icon(Icons.download_rounded, size: 18),
                          label: const Text('Salvar imagem'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          key: _shareButtonKey,
                          onPressed: ready ? _share : null,
                          icon: _busy
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.ios_share_rounded, size: 18),
                          label: const Text('Compartilhar'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Abre a prévia do card. Ponto único de entrada — a estante e o formulário
/// chamam por aqui.
Future<void> openShareReview(BuildContext context, ItemModel item) {
  return Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => ShareReviewScreen(item: item)),
  );
}
