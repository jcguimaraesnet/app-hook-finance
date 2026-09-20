// Spec: docs/specs/features/captura-notificacoes.md
//
// Tela de Configurações — atualmente única seção é "Captura de notificações"
// (Android-only). Toggle de ativar, status de permissão, seletor de app,
// regex de filtro de título, e status (última captura, último erro).

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:notification_listener_service/notification_listener_service.dart';

import '../../core/format/dates.dart';
import '../../state/notification_capture_provider.dart';
import '../../theme/bloom_colors.dart';
import '../../theme/bloom_typography.dart';
import '../../widgets/bloom/bloom_card.dart';
import '../../widgets/bloom/bloom_screen.dart';
import '../../widgets/bloom/screen_header.dart';
import 'app_picker_sheet.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage>
    with WidgetsBindingObserver {
  late final TextEditingController _regexCtrl;
  bool _permGranted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _regexCtrl = TextEditingController(
      text: ref.read(notificationCaptureProvider).titleRegex,
    );
    _checkPermission();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _regexCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) _checkPermission();
  }

  Future<void> _checkPermission() async {
    if (kIsWeb || !Platform.isAndroid) return;
    final ok = await NotificationListenerService.isPermissionGranted();
    if (!mounted) return;
    setState(() => _permGranted = ok);
  }

  Future<void> _requestPermission() async {
    if (kIsWeb || !Platform.isAndroid) return;
    final ok = await NotificationListenerService.requestPermission();
    if (!mounted) return;
    setState(() => _permGranted = ok);
  }

  Future<void> _onPickApp() async {
    final picked = await showAppPickerSheet(context);
    if (picked != null && mounted) {
      await ref.read(notificationCaptureProvider.notifier).setPackage(picked);
    }
  }

  Future<void> _onToggleEnabled(bool v) async {
    if (v && !_permGranted) {
      await _requestPermission();
      if (!_permGranted) return;
    }
    await ref.read(notificationCaptureProvider.notifier).setEnabled(v);
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(notificationCaptureProvider);
    final isAndroid = !kIsWeb && Platform.isAndroid;
    final canEnable =
        isAndroid && s.packageName.trim().isNotEmpty;

    return BloomScreen(
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          bottom: 24 + MediaQuery.of(context).padding.bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ScreenHeader(title: 'Configurações', showBack: true),
            const SizedBox(height: 18),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: Text(
                'CAPTURA DE NOTIFICAÇÕES',
                style: BloomTypography.kicker(),
              ),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: Text(
                'Lê notificações do app do seu banco e envia pro webhook do hook-finance — substitui o Tasker/IFTTT.',
                style: BloomTypography.geist(
                  fontSize: 12,
                  color: BloomColors.muted,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: BloomCard(
                padding: const EdgeInsets.fromLTRB(16, 12, 12, 16),
                borderRadius: BorderRadius.circular(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!isAndroid)
                      _IosNotice()
                    else ...[
                      _EnableRow(
                        enabled: s.enabled,
                        canEnable: canEnable,
                        onChanged: _onToggleEnabled,
                      ),
                      const Divider(height: 22, color: BloomColors.divider),
                      _PermissionRow(
                        granted: _permGranted,
                        onRequest: _requestPermission,
                      ),
                      const Divider(height: 22, color: BloomColors.divider),
                      _AppRow(
                        packageName: s.packageName,
                        onPick: _onPickApp,
                      ),
                      const Divider(height: 22, color: BloomColors.divider),
                      _RegexField(
                        controller: _regexCtrl,
                        onSaved: (v) => ref
                            .read(notificationCaptureProvider.notifier)
                            .setTitleRegex(v.trim()),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (isAndroid) ...[
              const SizedBox(height: 18),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: Text('STATUS', style: BloomTypography.kicker()),
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: _StatusCard(state: s),
              ),
              const SizedBox(height: 18),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: Text(
                  'Limitação atual: o listener depende da app estar viva (em foreground ou no recents). '
                  'Android pode encerrar o processo após um tempo de inatividade — notificações que '
                  'chegarem nesse intervalo serão perdidas. Backup recomendado: manter Tasker/IFTTT '
                  'em paralelo até confirmar estabilidade.',
                  style: BloomTypography.geist(
                    fontSize: 11,
                    color: BloomColors.muted,
                    height: 1.5,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 22),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 22),
              child: _VersionFooter(),
            ),
          ],
        ),
      ),
    );
  }
}

/// Versão do binário em execução. Lida em runtime (não hardcoded) para não
/// divergir do pubspec: no web vem do version.json gerado no build, no Android
/// do PackageInfo. Útil para saber se o APK instalado é o da release atual —
/// depois da migração de Origem, APK velho mostra zero em tudo.
class _VersionFooter extends StatefulWidget {
  const _VersionFooter();

  @override
  State<_VersionFooter> createState() => _VersionFooterState();
}

class _VersionFooterState extends State<_VersionFooter> {
  String? _label;

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (!mounted) return;
      setState(() => _label = 'hook-finance ${info.version} (${info.buildNumber})');
    }).catchError((_) {
      if (mounted) setState(() => _label = 'hook-finance — versão indisponível');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        _label ?? '',
        style: BloomTypography.mono(fontSize: 11, color: BloomColors.muted),
      ),
    );
  }
}

class _IosNotice extends StatelessWidget {
  const _IosNotice();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline,
              size: 20, color: BloomColors.muted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Disponível apenas no Android. iOS não permite que apps leiam '
              'notificações de outros apps (restrição da Apple).',
              style: BloomTypography.geist(
                fontSize: 12.5,
                color: BloomColors.inkSoft,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EnableRow extends StatelessWidget {
  final bool enabled;
  final bool canEnable;
  final ValueChanged<bool> onChanged;

  const _EnableRow({
    required this.enabled,
    required this.canEnable,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ativar captura',
                style: BloomTypography.geist(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: BloomColors.ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                canEnable
                    ? 'Filtra e envia notificações para o backend.'
                    : 'Selecione um app antes de ativar.',
                style: BloomTypography.geist(
                  fontSize: 11.5,
                  color: BloomColors.muted,
                ),
              ),
            ],
          ),
        ),
        Switch.adaptive(
          value: enabled,
          onChanged: canEnable ? onChanged : null,
          activeThumbColor: BloomColors.violet,
        ),
      ],
    );
  }
}

class _PermissionRow extends StatelessWidget {
  final bool granted;
  final VoidCallback onRequest;

  const _PermissionRow({required this.granted, required this.onRequest});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          granted ? Icons.check_circle : Icons.warning_amber_rounded,
          color: granted ? BloomColors.good : BloomColors.amber,
          size: 22,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                granted
                    ? 'Permissão concedida'
                    : 'Permissão necessária',
                style: BloomTypography.geist(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: BloomColors.ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                granted
                    ? 'Acesso a notificações está ativo nas configurações do sistema.'
                    : 'Toque em "Conceder" e ative "Hook Finance" na lista.',
                style: BloomTypography.geist(
                  fontSize: 11.5,
                  color: BloomColors.muted,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
        if (!granted)
          TextButton(
            onPressed: onRequest,
            style: TextButton.styleFrom(foregroundColor: BloomColors.violet),
            child: const Text('Conceder'),
          ),
      ],
    );
  }
}

class _AppRow extends StatelessWidget {
  final String packageName;
  final VoidCallback onPick;

  const _AppRow({required this.packageName, required this.onPick});

  @override
  Widget build(BuildContext context) {
    final empty = packageName.trim().isEmpty;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'App do banco',
                style: BloomTypography.geist(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: BloomColors.ink,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                empty ? 'Nenhum app selecionado' : packageName,
                style: empty
                    ? BloomTypography.geist(
                        fontSize: 12,
                        color: BloomColors.muted,
                      )
                    : BloomTypography.mono(
                        fontSize: 12,
                        color: BloomColors.inkSoft,
                      ),
              ),
            ],
          ),
        ),
        TextButton(
          onPressed: onPick,
          style: TextButton.styleFrom(foregroundColor: BloomColors.violet),
          child: Text(empty ? 'Escolher' : 'Trocar'),
        ),
      ],
    );
  }
}

class _RegexField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onSaved;

  const _RegexField({required this.controller, required this.onSaved});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Filtro de título (regex)',
          style: BloomTypography.geist(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: BloomColors.ink,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Opcional. Vazio = sem filtro. Ex.: ^Compra aprovada',
          style: BloomTypography.geist(
            fontSize: 11.5,
            color: BloomColors.muted,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          autocorrect: false,
          style: BloomTypography.mono(fontSize: 12.5),
          decoration: const InputDecoration(
            hintText: '^Compra aprovada',
            isDense: true,
          ),
          onChanged: onSaved,
        ),
      ],
    );
  }
}

class _StatusCard extends StatelessWidget {
  final NotificationCaptureState state;

  const _StatusCard({required this.state});

  @override
  Widget build(BuildContext context) {
    return BloomCard(
      padding: const EdgeInsets.all(14),
      borderRadius: BorderRadius.circular(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                state.lastCaptureAt != null
                    ? Icons.cloud_done_outlined
                    : Icons.cloud_off_outlined,
                size: 18,
                color: state.lastCaptureAt != null
                    ? BloomColors.good
                    : BloomColors.muted,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  state.lastCaptureAt == null
                      ? 'Nenhuma captura ainda.'
                      : 'Última captura: ${relativeTime(state.lastCaptureAt!)}',
                  style: BloomTypography.geist(
                    fontSize: 13,
                    color: BloomColors.ink,
                  ),
                ),
              ),
            ],
          ),
          if (state.lastCaptureTitle != null &&
              state.lastCaptureTitle!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 28),
              child: Text(
                state.lastCaptureTitle!,
                style: BloomTypography.geist(
                  fontSize: 11.5,
                  color: BloomColors.muted,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
          if (state.lastError != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: BloomColors.bad.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.error_outline,
                      size: 16, color: BloomColors.bad),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      state.lastError!,
                      style: BloomTypography.geist(
                        fontSize: 12,
                        color: BloomColors.bad,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () =>
                  GoRouter.of(context).go('/settings/captures'),
              icon: const Icon(Icons.list_alt, size: 18),
              label: const Text('Ver histórico'),
              style: TextButton.styleFrom(
                  foregroundColor: BloomColors.violet),
            ),
          ),
        ],
      ),
    );
  }

}
