import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class AdaptiveNetworkImage extends StatefulWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget fallback;

  const AdaptiveNetworkImage({
    super.key,
    required this.imageUrl,
    required this.fallback,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
  });

  @override
  State<AdaptiveNetworkImage> createState() => _AdaptiveNetworkImageState();
}

class _AdaptiveNetworkImageState extends State<AdaptiveNetworkImage> {
  late final List<String> _candidateUrls;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _candidateUrls = _buildCandidates(widget.imageUrl);
  }

  List<String> _buildCandidates(String originalUrl) {
    final normalized = originalUrl
        .replaceFirst('http://', 'https://')
        .replaceAll('&edge=curl', '')
        .replaceAll('?edge=curl', '');

    final candidates = <String>[normalized];

    if (kIsWeb) {
      final encoded = Uri.encodeComponent(normalized);
      candidates.add('https://images.weserv.nl/?url=$encoded');
      candidates.add('https://images.weserv.nl/?url=$encoded&w=400');
    }

    return candidates.toSet().toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_candidateUrls.isEmpty) return widget.fallback;

    return Image.network(
      _candidateUrls[_currentIndex],
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      errorBuilder: (_, __, ___) {
        if (_currentIndex < _candidateUrls.length - 1) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _currentIndex++;
              });
            }
          });
          return const SizedBox.shrink();
        }
        return widget.fallback;
      },
    );
  }
}
