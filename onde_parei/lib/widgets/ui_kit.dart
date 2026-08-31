import 'package:flutter/material.dart';

import '../models/item_model.dart';
import '../theme/app_theme.dart';
import 'adaptive_network_image.dart';

/// Selo do tipo da obra (Livro / Mangá / Manhwa / Manhua).
class TypeBadge extends StatelessWidget {
  final String label;
  final Color color;
  final bool compact;

  const TypeBadge({
    super.key,
    required this.label,
    required this.color,
    this.compact = false,
  });

  factory TypeBadge.forItem(ItemModel item, {bool compact = false}) {
    return TypeBadge(
      label: item.type.label,
      color: AppColors.forType(item.type.name),
      compact: compact,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 7 : 9,
        vertical: compact ? 2 : 3.5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: compact ? 10 : 11,
        ),
      ),
    );
  }
}

/// Pílula do status de leitura.
class StatusPill extends StatelessWidget {
  final ReadingStatus status;
  final bool compact;

  const StatusPill({super.key, required this.status, this.compact = false});

  static Color colorOf(ReadingStatus status) {
    switch (status) {
      case ReadingStatus.read:
        return AppColors.statusRead;
      case ReadingStatus.reading:
        return AppColors.statusReading;
      case ReadingStatus.wantToRead:
        return AppColors.statusWant;
    }
  }

  static IconData iconOf(ReadingStatus status) {
    switch (status) {
      case ReadingStatus.read:
        return Icons.check_circle_rounded;
      case ReadingStatus.reading:
        return Icons.auto_stories_rounded;
      case ReadingStatus.wantToRead:
        return Icons.bookmark_add_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = colorOf(status);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(iconOf(status), size: compact ? 11 : 13, color: color),
          const SizedBox(width: 5),
          Text(
            status.label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: compact ? 10.5 : 11.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// Barra de progresso fina com rótulo opcional.
class ReadingProgressBar extends StatelessWidget {
  final double value;
  final Color color;
  final double height;

  const ReadingProgressBar({
    super.key,
    required this.value,
    required this.color,
    this.height = 5,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: value.clamp(0.0, 1.0)),
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
        builder: (context, animated, _) => LinearProgressIndicator(
          value: animated,
          minHeight: height,
          backgroundColor: scheme.outlineVariant,
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
      ),
    );
  }
}

/// Cabeçalho de seção com ação opcional à direita.
class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? action;
  final EdgeInsetsGeometry padding;

  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
    this.padding = const EdgeInsets.fromLTRB(16, 20, 16, 8),
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.headlineSmall),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: theme.textTheme.bodySmall),
                ],
              ],
            ),
          ),
          if (action != null) action!,
        ],
      ),
    );
  }
}

/// Estado vazio padronizado.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: scheme.primary.withValues(alpha: 0.10),
                border: Border.all(
                  color: scheme.primary.withValues(alpha: 0.25),
                ),
              ),
              child: Icon(icon, size: 42, color: scheme.primary),
            ),
            const SizedBox(height: 22),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            if (action != null) ...[const SizedBox(height: 22), action!],
          ],
        ),
      ),
    );
  }
}

/// Capa com proporção de livro, sombra e fallback tipográfico.
class CoverArt extends StatelessWidget {
  final String? imageUrl;
  final String title;
  final IconData fallbackIcon;
  final double? width;
  final double? height;
  final double radius;
  final int? decodeWidth;

  const CoverArt({
    super.key,
    required this.imageUrl,
    required this.title,
    this.fallbackIcon = Icons.menu_book_rounded,
    this.width,
    this.height,
    this.radius = AppRadius.sm,
    this.decodeWidth,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final fallback = Container(
      color: scheme.surfaceContainerHigh,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            fallbackIcon,
            size: 24,
            color: scheme.primary.withValues(alpha: 0.65),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.25,
            ),
          ),
        ],
      ),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: width,
        height: height,
        child: (imageUrl == null || imageUrl!.trim().isEmpty)
            ? fallback
            : AdaptiveNetworkImage(
                imageUrl: imageUrl!,
                fit: BoxFit.cover,
                decodeWidth: decodeWidth ?? width?.round(),
                fallback: fallback,
              ),
      ),
    );
  }
}

/// Snackbars consistentes em todo o app.
abstract final class AppSnack {
  static void show(
    BuildContext context,
    String message, {
    IconData icon = Icons.check_circle_rounded,
    Color? accent,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final color = accent ?? scheme.primary;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 3),
          content: Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 10),
              Expanded(child: Text(message)),
            ],
          ),
        ),
      );
  }

  static void error(BuildContext context, String message) => show(
    context,
    message,
    icon: Icons.error_outline_rounded,
    accent: Theme.of(context).colorScheme.error,
  );
}
