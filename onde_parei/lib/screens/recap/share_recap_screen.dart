import 'package:flutter/material.dart';

import '../../services/recap_service.dart';
import '../../services/share_service.dart';
import '../../widgets/adaptive_network_image.dart';
import '../../widgets/recap_card.dart';
import '../../widgets/ui_kit.dart';

/// Prévia do card da retrospectiva. Irmã de `ShareReviewScreen`: o que está na
/// tela é exatamente o que vira PNG, e a capa é resolvida **antes** de liberar
/// a captura — no Web só entra na imagem capa servida com CORS.
class ShareRecapScreen extends StatefulWidget {
  final ReadingRecap recap;
  final String readerName;

  const ShareRecapScreen({
    super.key,
    required this.recap,
    this.readerName = '',
  });

  @override
  State<ShareRecapScreen> createState() => _ShareRecapScreenState();
}

class _ShareRecapScreenState extends State<ShareRecapScreen> {
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

  Future<void> _resolveCover() async {
    final url = widget.recap.favorite?.imageUrl;
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
    final recap = widget.recap;
    final favorite = recap.favorite;
    final destaque = favorite == null ? '' : ' A melhor: ${favorite.name}.';
    return 'Terminei ${recap.total} '
        '${recap.total == 1 ? 'obra' : 'obras'} em ${recap.periodLabel}.'
        '$destaque '
        '${recap.isMonthly ? 'Minha cápsula' : 'Minha retrospectiva'} '
        'no Onde Parei? https://onde-parei-ea32c.web.app';
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

  String get _fileName => ShareService.fileNameFor(
    widget.recap.isMonthly
        ? 'capsula-${widget.recap.periodLabel}'
        : 'retrospectiva-${widget.recap.year}',
  );

  Future<void> _share() {
    return _run(() async {
      final bytes = await ShareService.capture(_cardKey);
      final box =
          _shareButtonKey.currentContext?.findRenderObject() as RenderBox?;
      return ShareService.shareImage(
        bytes: bytes,
        fileName: _fileName,
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
        fileName: _fileName,
      );
      return saved ? ShareOutcome.downloaded : ShareOutcome.unavailable;
    });
  }

  @override
  Widget build(BuildContext context) {
    final ready = !_resolvingCover && !_busy;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.recap.isMonthly
              ? 'Cápsula de ${widget.recap.periodLabel}'
              : 'Retrospectiva ${widget.recap.year}',
        ),
      ),
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
                      child: RecapCard(
                        recap: widget.recap,
                        readerName: widget.readerName,
                        favoriteCoverUrl: _coverUrl,
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

/// Abre a prévia do card da retrospectiva. Ponto único de entrada.
Future<void> openShareRecap(
  BuildContext context, {
  required ReadingRecap recap,
  String readerName = '',
}) {
  return Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => ShareRecapScreen(recap: recap, readerName: readerName),
    ),
  );
}
