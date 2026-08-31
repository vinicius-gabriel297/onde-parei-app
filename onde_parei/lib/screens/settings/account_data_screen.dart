import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/item_model.dart';
import '../../services/auth_service.dart';
import '../../services/export_service.dart';
import '../../services/file_download.dart';
import '../../services/firestore_service.dart';
import '../../services/search_history_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ui_kit.dart';

/// Tela "Conta e dados": exportar a estante e excluir a conta.
///
/// Existe para atender a LGPD (acesso, portabilidade e eliminação) e a
/// exigência da Google Play de um caminho de exclusão dentro do app.
class AccountDataScreen extends StatefulWidget {
  const AccountDataScreen({super.key});

  @override
  State<AccountDataScreen> createState() => _AccountDataScreenState();
}

class _AccountDataScreenState extends State<AccountDataScreen> {
  bool _exporting = false;
  bool _deleting = false;

  // ─── Exportação ─────────────────────────────────────────────────────────────

  Future<void> _export({required bool asJson}) async {
    final auth = context.read<AuthService>();
    final firestore = context.read<FirestoreService>();
    final user = auth.currentUser;
    if (user == null) return;

    setState(() => _exporting = true);
    try {
      final items = await firestore.fetchUserItemsOnce(user.uid);
      final content = asJson
          ? ExportService.buildJson(
              userId: user.uid,
              email: user.email,
              displayName: user.displayName,
              items: items,
            )
          : ExportService.buildCsv(items);

      final saved = await downloadTextFile(
        ExportService.fileName(asJson ? 'json' : 'csv'),
        content,
        asJson ? 'application/json' : 'text/csv',
      );

      if (!mounted) return;

      if (saved) {
        AppSnack.show(
          context,
          items.length == 1
              ? '1 título exportado.'
              : '${items.length} títulos exportados.',
        );
      } else {
        // Sem download nativo: entrega o conteúdo pela área de transferência.
        await _showCopyFallback(content, items.length);
      }
    } catch (e) {
      if (mounted) AppSnack.error(context, '$e');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _showCopyFallback(String content, int count) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Seus dados'),
        content: Text(
          count == 1
              ? '1 título pronto para copiar. Cole em um bloco de notas e '
                    'salve o arquivo onde preferir.'
              : '$count títulos prontos para copiar. Cole em um bloco de notas '
                    'e salve o arquivo onde preferir.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Fechar'),
          ),
          FilledButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: content));
              if (dialogContext.mounted) Navigator.pop(dialogContext);
              if (mounted) AppSnack.show(context, 'Copiado.');
            },
            child: const Text('Copiar'),
          ),
        ],
      ),
    );
  }

  // ─── Exclusão ───────────────────────────────────────────────────────────────

  Future<void> _deleteAccount() async {
    final auth = context.read<AuthService>();
    final firestore = context.read<FirestoreService>();
    final history = context.read<SearchHistoryService>();
    final user = auth.currentUser;
    final email = user?.email;

    if (user == null || email == null) {
      AppSnack.error(context, 'Faça login novamente para excluir a conta.');
      return;
    }

    final confirmed = await _confirmDeletion();
    if (confirmed != true || !mounted) return;

    final password = await _askPassword();
    if (password == null || password.isEmpty || !mounted) return;

    setState(() => _deleting = true);
    try {
      // Confirma a identidade antes de tocar em qualquer dado.
      await auth.reauthenticate(email, password);

      // Ordem obrigatória: os itens primeiro. As regras do Firestore exigem
      // `request.auth.uid`, então depois de excluir a conta no Auth ninguém
      // mais consegue apagá-los e eles ficariam órfãos para sempre.
      await firestore.deleteAllUserData(user.uid);
      await history.clear();
      await auth.deleteAccount();

      // O AuthWrapper escuta authStateChanges e volta sozinho para o login.
    } catch (e) {
      if (mounted) {
        setState(() => _deleting = false);
        AppSnack.error(context, '$e');
      }
    }
  }

  Future<bool?> _confirmDeletion() => showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Excluir conta'),
      content: const Text(
        'Isso apaga em definitivo sua conta e todos os títulos da sua estante, '
        'incluindo progresso e notas. A ação não pode ser desfeita e os dados '
        'não podem ser recuperados depois.\n\n'
        'Se quiser guardar uma cópia, cancele e exporte seus dados primeiro.',
      ),
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
          child: const Text('Excluir tudo'),
        ),
      ],
    ),
  );

  Future<String?> _askPassword() {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirme sua senha'),
        content: TextField(
          controller: controller,
          obscureText: true,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Senha da conta',
            isDense: true,
          ),
          onSubmitted: (value) => Navigator.pop(dialogContext, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    ).whenComplete(controller.dispose);
  }

  // ─── UI ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final firestore = context.read<FirestoreService>();
    final user = context.read<AuthService>().currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text('Conta e dados')),
      body: AbsorbPointer(
        absorbing: _deleting,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
          children: [
            Text(
              user?.email ?? 'Não autenticado',
              style: theme.textTheme.bodySmall,
            ),

            const SizedBox(height: 22),
            Text('Exportar', style: theme.textTheme.titleSmall),
            const SizedBox(height: 6),
            Text(
              'Baixe uma cópia da sua estante. O arquivo é gerado no seu '
              'aparelho e não passa por nenhum servidor.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 10),
            _ActionTile(
              icon: Icons.data_object_rounded,
              title: 'Exportar em JSON',
              subtitle: 'Formato completo, com todos os campos',
              trailing: _exporting ? const _Spinner() : null,
              onTap: _exporting ? null : () => _export(asJson: true),
            ),
            const SizedBox(height: 10),
            _ActionTile(
              icon: Icons.table_chart_outlined,
              title: 'Exportar em CSV',
              subtitle: 'Abre no Excel, Planilhas ou Numbers',
              trailing: _exporting ? const _Spinner() : null,
              onTap: _exporting ? null : () => _export(asJson: false),
            ),

            const SizedBox(height: 28),
            Text(
              'Excluir conta',
              style: theme.textTheme.titleSmall?.copyWith(color: scheme.error),
            ),
            const SizedBox(height: 6),
            StreamBuilder<List<ItemModel>>(
              stream: user == null
                  ? const Stream<List<ItemModel>>.empty()
                  : firestore.getUserItems(user.uid),
              builder: (context, snapshot) {
                final count = snapshot.data?.length;
                return Text(
                  count == null
                      ? 'Apaga a conta e tudo que está guardado nela.'
                      : count == 1
                      ? 'Apaga a conta e o único título da sua estante. '
                            'Não dá para desfazer.'
                      : 'Apaga a conta e os $count títulos da sua estante. '
                            'Não dá para desfazer.',
                  style: theme.textTheme.bodySmall,
                );
              },
            ),
            const SizedBox(height: 10),
            _ActionTile(
              icon: Icons.delete_forever_rounded,
              iconColor: scheme.error,
              title: 'Excluir minha conta',
              subtitle: 'Remoção permanente dos dados',
              trailing: _deleting ? const _Spinner() : null,
              onTap: _deleting ? null : _deleteAccount,
            ),

            const SizedBox(height: 24),
            Text(
              'Também é possível pedir a exclusão sem o app, pela página '
              'onde-parei-ea32c.web.app/excluir-conta.',
              style: theme.textTheme.labelSmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _Spinner extends StatelessWidget {
  const _Spinner();

  @override
  Widget build(BuildContext context) => const SizedBox(
    width: 18,
    height: 18,
    child: CircularProgressIndicator(strokeWidth: 2),
  );
}

// Mesma aparência dos itens de ajustes, sem exportar o widget privado de lá.
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
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleSmall),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(subtitle, style: theme.textTheme.labelSmall),
                    ],
                  ],
                ),
              ),
              trailing ?? const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}
