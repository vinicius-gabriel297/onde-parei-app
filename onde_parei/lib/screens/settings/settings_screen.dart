import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/item_model.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/theme_controller.dart';
import '../../widgets/ui_kit.dart';
import 'account_data_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with AutomaticKeepAliveClientMixin {
  final _nameController = TextEditingController();

  bool _savingName = false;
  bool _migrating = false;
  bool _nameDirty = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthService>().currentUser;
    _nameController.text = user?.displayName ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveName() async {
    setState(() => _savingName = true);
    try {
      await context.read<AuthService>().updateDisplayName(_nameController.text);
      if (!mounted) return;
      setState(() => _nameDirty = false);
      AppSnack.show(context, 'Nome atualizado.');
    } catch (e) {
      if (mounted) AppSnack.error(context, '$e');
    } finally {
      if (mounted) setState(() => _savingName = false);
    }
  }

  Future<void> _fixCovers() async {
    final user = context.read<AuthService>().currentUser;
    if (user == null) return;

    setState(() => _migrating = true);
    try {
      final count = await context
          .read<FirestoreService>()
          .migrateUserImageUrlsToHttps(user.uid);
      if (!mounted) return;
      AppSnack.show(
        context,
        count == 0
            ? 'Nenhuma capa precisava de correção.'
            : '$count ${count == 1 ? 'capa corrigida' : 'capas corrigidas'}.',
      );
    } catch (e) {
      if (mounted) AppSnack.error(context, '$e');
    } finally {
      if (mounted) setState(() => _migrating = false);
    }
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sair da conta'),
        content: const Text('Você precisará entrar novamente para acessar sua estante.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Sair'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await context.read<AuthService>().signOut();
    } catch (e) {
      if (mounted) AppSnack.error(context, '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final auth = context.read<AuthService>();
    final firestore = context.read<FirestoreService>();
    final themeController = context.watch<ThemeController>();
    final user = auth.currentUser;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
          children: [
            Text('Meu perfil', style: theme.textTheme.headlineMedium),
            const SizedBox(height: 2),
            Text(
              user?.email ?? 'Não autenticado',
              style: theme.textTheme.bodySmall,
            ),

            const SizedBox(height: 22),

            // Resumo da estante
            StreamBuilder<List<ItemModel>>(
              stream: user == null
                  ? const Stream<List<ItemModel>>.empty()
                  : firestore.getUserItems(user.uid),
              builder: (context, snapshot) {
                final items = snapshot.data ?? const <ItemModel>[];
                final stats = FirestoreService.statsFrom(items);
                return _SummaryCard(stats: stats);
              },
            ),

            const SizedBox(height: 26),
            Text('Nome de exibição', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
                    onChanged: (_) {
                      if (!_nameDirty) setState(() => _nameDirty = true);
                    },
                    decoration: const InputDecoration(
                      hintText: 'Como quer ser chamado?',
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton(
                  onPressed: (_savingName || !_nameDirty) ? null : _saveName,
                  child: _savingName
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Salvar'),
                ),
              ],
            ),

            const SizedBox(height: 26),
            Text('Aparência', style: theme.textTheme.titleSmall),
            const SizedBox(height: 10),
            _ThemeSelector(
              mode: themeController.mode,
              onChanged: themeController.setMode,
            ),

            const SizedBox(height: 26),
            Text('Manutenção', style: theme.textTheme.titleSmall),
            const SizedBox(height: 10),
            _ActionTile(
              icon: Icons.image_outlined,
              title: 'Corrigir capas antigas',
              subtitle: 'Converte endereços http:// para https://',
              trailing: _migrating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.chevron_right_rounded),
              onTap: _migrating ? null : _fixCovers,
            ),
            const SizedBox(height: 10),
            _ActionTile(
              icon: Icons.refresh_rounded,
              title: 'Limpar cache de busca',
              subtitle: 'Força uma nova consulta nas APIs externas',
              onTap: () {
                ApiService.reset();
                AppSnack.show(context, 'Cache de busca limpo.');
              },
            ),

            const SizedBox(height: 26),
            Text('Conta e dados', style: theme.textTheme.titleSmall),
            const SizedBox(height: 10),
            _ActionTile(
              icon: Icons.shield_outlined,
              title: 'Conta e dados',
              subtitle: 'Exportar sua estante ou excluir a conta',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const AccountDataScreen(),
                ),
              ),
            ),

            const SizedBox(height: 26),
            _ActionTile(
              icon: Icons.logout_rounded,
              iconColor: scheme.error,
              title: 'Sair da conta',
              subtitle: user?.email ?? '',
              onTap: _signOut,
            ),

            const SizedBox(height: 30),
            Center(
              child: Column(
                children: [
                  Icon(
                    Icons.auto_stories_rounded,
                    size: 26,
                    color: scheme.primary.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 8),
                  Text('Onde Parei? · 1.1.1', style: theme.textTheme.labelSmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Resumo ───────────────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final Map<String, dynamic> stats;

  const _SummaryCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final average = (stats['averageRating'] as double?) ?? 0;

    Widget cell(String value, String label, Color color) => Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: theme.textTheme.labelSmall,
          ),
        ],
      ),
    );

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          cell('${stats['totalItems'] ?? 0}', 'títulos', scheme.primary),
          cell(
            '${stats['totalBooks'] ?? 0}',
            'livros',
            AppColors.typeBook,
          ),
          cell(
            '${stats['totalMangas'] ?? 0}',
            'quadrinhos',
            AppColors.typeManga,
          ),
          cell(
            average > 0 ? average.toStringAsFixed(1) : '—',
            'nota média',
            AppColors.gold,
          ),
        ],
      ),
    );
  }
}

// ─── Seletor de tema ──────────────────────────────────────────────────────────

class _ThemeSelector extends StatelessWidget {
  final ThemeMode mode;
  final ValueChanged<ThemeMode> onChanged;

  const _ThemeSelector({required this.mode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    const options = <(ThemeMode, String, IconData)>[
      (ThemeMode.light, 'Claro', Icons.light_mode_rounded),
      (ThemeMode.dark, 'Escuro', Icons.dark_mode_rounded),
      (ThemeMode.system, 'Sistema', Icons.brightness_auto_rounded),
    ];

    final scheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        for (final (value, label, icon) in options) ...[
          Expanded(
            child: Material(
              color: mode == value
                  ? scheme.primary.withValues(alpha: 0.14)
                  : scheme.surfaceContainer,
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadius.md),
                onTap: () => onChanged(value),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(
                      color: mode == value
                          ? scheme.primary
                          : scheme.outlineVariant,
                      width: mode == value ? 1.6 : 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        icon,
                        size: 20,
                        color: mode == value
                            ? scheme.primary
                            : scheme.onSurfaceVariant,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        label,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: mode == value
                              ? scheme.primary
                              : scheme.onSurfaceVariant,
                          fontWeight: mode == value
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (value != options.last.$1) const SizedBox(width: 8),
        ],
      ],
    );
  }
}

// ─── Item de ação ─────────────────────────────────────────────────────────────

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.iconColor,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = iconColor ?? scheme.primary;

    return Material(
      color: scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleMedium),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
        ),
      ),
    );
  }
}
