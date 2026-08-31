import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Imagem de rede resiliente:
/// - normaliza http -> https (evita mixed content no Web);
/// - no Web, cai para um proxy de imagens quando a origem bloqueia hotlink;
/// - decodifica no tamanho de exibição (`cacheWidth`), o que reduz muito o
///   uso de memória em grades de capas;
/// - faz fade-in em vez de "pipocar" na tela.
class AdaptiveNetworkImage extends StatefulWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget fallback;

  /// Largura alvo em pixels lógicos, usada para o downscale de decodificação.
  final int? decodeWidth;

  const AdaptiveNetworkImage({
    super.key,
    required this.imageUrl,
    required this.fallback,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.decodeWidth,
  });

  @override
  State<AdaptiveNetworkImage> createState() => _AdaptiveNetworkImageState();
}

class _AdaptiveNetworkImageState extends State<AdaptiveNetworkImage> {
  late List<String> _candidateUrls;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _candidateUrls = _buildCandidates(widget.imageUrl);
  }

  @override
  void didUpdateWidget(covariant AdaptiveNetworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _candidateUrls = _buildCandidates(widget.imageUrl);
      _currentIndex = 0;
    }
  }

  static List<String> _buildCandidates(String originalUrl) {
    final normalized = originalUrl
        .trim()
        .replaceFirst('http://', 'https://')
        .replaceAll('&edge=curl', '')
        .replaceAll('?edge=curl', '');

    if (normalized.isEmpty) return const [];

    final candidates = <String>[normalized];

    if (kIsWeb) {
      final encoded = Uri.encodeComponent(normalized);
      candidates.add('https://images.weserv.nl/?url=$encoded&w=500&output=webp');
      candidates.add('https://images.weserv.nl/?url=$encoded');
    }

    return candidates.toSet().toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_candidateUrls.isEmpty) return widget.fallback;

    final devicePixelRatio = MediaQuery.maybeDevicePixelRatioOf(context) ?? 2.0;
    final targetWidth = widget.decodeWidth ?? widget.width?.round();
    final cacheWidth = targetWidth != null
        ? (targetWidth * devicePixelRatio).round().clamp(64, 1200)
        : null;

    return Image.network(
      _candidateUrls[_currentIndex],
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      cacheWidth: cacheWidth,
      gaplessPlayback: true,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded) return child;
        return AnimatedOpacity(
          opacity: frame == null ? 0 : 1,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOut,
          child: child,
        );
      },
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return const _CoverShimmer();
      },
      errorBuilder: (_, __, ___) {
        if (_currentIndex < _candidateUrls.length - 1) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _currentIndex++);
          });
          return const _CoverShimmer();
        }
        return widget.fallback;
      },
    );
  }
}

/// Placeholder animado exibido enquanto a capa carrega.
class _CoverShimmer extends StatefulWidget {
  const _CoverShimmer();

  @override
  State<_CoverShimmer> createState() => _CoverShimmerState();
}

class _CoverShimmerState extends State<_CoverShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(-1.4 + 2.8 * t, -0.6),
              end: Alignment(-0.4 + 2.8 * t, 0.6),
              colors: [
                scheme.surfaceContainer,
                scheme.surfaceContainerHigh,
                scheme.surfaceContainer,
              ],
              stops: const [0.1, 0.5, 0.9],
            ),
          ),
          child: const SizedBox.expand(),
        );
      },
    );
  }
}

/// Bloco retangular animado para skeletons de listas.
class SkeletonBox extends StatelessWidget {
  final double? width;
  final double height;
  final double radius;

  const SkeletonBox({
    super.key,
    this.width,
    required this.height,
    this.radius = 6,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: width,
        height: height,
        child: const _CoverShimmer(),
      ),
    );
  }
}
