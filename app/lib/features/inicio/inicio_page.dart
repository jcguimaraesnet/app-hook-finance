// Spec: docs/specs/pages/inicio.md
// Visão pessoal — donut + buckets + comparativo + recentes.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/format/dates.dart';
import '../../core/format/money.dart';
import '../../core/rules/bucket_deltas.dart';
import '../../core/rules/origem_totals.dart';
import '../../core/types.dart';
import '../../state/auth_provider.dart';
import '../../state/data_providers.dart';
import '../../state/nav_provider.dart';
import '../../theme/bloom_colors.dart';
import '../../theme/bloom_typography.dart';
import '../../widgets/bloom/bloom_bottom_nav.dart';
import '../../widgets/bloom/bloom_card.dart';
import '../../widgets/bloom/bloom_donut.dart';
import '../../widgets/bloom/bloom_logo.dart';
import '../../widgets/bloom/month_selector.dart';
import '../../widgets/bloom/recent_entry_row.dart';
import '../lancamento/edit_dialog.dart';

class InicioPage extends ConsumerStatefulWidget {
  const InicioPage({super.key});

  @override
  ConsumerState<InicioPage> createState() => _InicioPageState();
}

class _InicioPageState extends ConsumerState<InicioPage> {
  int? _selectedSegment;
  bool _refreshing = false;
  bool _creatingInvoice = false;

  @override
  Widget build(BuildContext context) {
    final person = ref.watch(selectedPersonProvider);
    final currentMonth = ref.watch(currentMonthProvider);
    final monthAsync = ref.watch(monthDataProvider(currentMonth));
    final prevAsync = ref.watch(previousMonthDataProvider);
    final lastAsync = ref.watch(lastEntriesProvider(3));

    final rows = monthAsync.value?.rows ?? const <ExpenseRow>[];
    final prevRows =
        prevAsync.value?.rows ?? const <ExpenseRow>[];

    final juCur = bucketsForPerson(rows, Person.julio);
    final daCur = bucketsForPerson(rows, Person.dani);
    final cur = person == Person.julio ? juCur : daCur;
    final prev = bucketsForPerson(prevRows, person);
    final deltas = bucketDeltas(current: cur, previous: prev);

    final loading = monthAsync.isLoading && !monthAsync.hasValue;

    Future<void> onRefresh() async {
      if (_refreshing) return;
      setState(() => _refreshing = true);
      final messenger = ScaffoldMessenger.of(context);
      ref.invalidate(monthDataProvider);
      ref.invalidate(previousMonthDataProvider);
      ref.invalidate(historicalSummaryProvider);
      ref.invalidate(lastEntriesProvider);
      String? error;
      try {
        await Future.wait<void>([
          ref.read(monthDataProvider(currentMonth).future),
          ref.read(lastEntriesProvider(3).future),
        ]);
      } catch (e) {
        error = '$e';
      }
      if (!mounted) return;
      setState(() => _refreshing = false);
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text(error == null
              ? 'Atualizado'
              : 'Falha ao atualizar: $error'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          backgroundColor:
              error == null ? BloomColors.ink : BloomColors.bad,
        ),
      );
    }

    Future<void> onNovaFatura() async {
      if (_creatingInvoice) return;
      final messenger = ScaffoldMessenger.of(context);

      // A data agora depende do estado da planilha (última fatura + 1 mês), então
      // o cliente não a computa localmente: busca no backend antes de confirmar.
      setState(() => _creatingInvoice = true);
      final NewInvoiceResponse preview;
      try {
        preview = await ref.read(apiProvider).previewNewInvoice();
      } catch (e) {
        if (mounted) setState(() => _creatingInvoice = false);
        messenger.showSnackBar(SnackBar(
          content: Text('Falha ao calcular a próxima fatura: $e'),
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
          backgroundColor: BloomColors.bad,
        ));
        return;
      }
      if (!mounted) return;
      if (!preview.ok || preview.invoiceClosing == null) {
        setState(() => _creatingInvoice = false);
        messenger.showSnackBar(SnackBar(
          content: Text(preview.error == 'unauthorized'
              ? 'Sessão expirada. Saia e entre de novo.'
              : 'Falha ao calcular a próxima fatura: ${preview.error ?? "erro desconhecido"}'),
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
          backgroundColor: BloomColors.bad,
        ));
        return;
      }
      final closing = preview.invoiceClosing!;

      if (!context.mounted) {
        setState(() => _creatingInvoice = false);
        return;
      }
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: Colors.white,
          title: Text(
            'Nova fatura',
            style: BloomTypography.display(fontSize: 18, letterSpacing: -0.2),
          ),
          content: Text(
            'Criar fatura de $closing? Vai inserir despesas fixas e parcelas pendentes.',
            style: const TextStyle(color: BloomColors.ink, fontSize: 14, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancelar', style: TextStyle(color: BloomColors.ink)),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: BloomColors.violet,
                foregroundColor: Colors.white,
              ),
              child: const Text('Criar'),
            ),
          ],
        ),
      );
      if (confirmed != true) {
        if (mounted) setState(() => _creatingInvoice = false);
        return;
      }
      if (!mounted) return;
      // _creatingInvoice já está true desde a chamada de preview.

      String? successMsg;
      String? errorMsg;
      try {
        final resp = await ref.read(apiProvider).newInvoice();
        if (resp.ok) {
          ref.invalidate(monthDataProvider);
          ref.invalidate(previousMonthDataProvider);
          ref.invalidate(historicalSummaryProvider);
          ref.invalidate(lastEntriesProvider);
          successMsg = 'Fatura ${resp.invoiceClosing ?? closing} criada — '
              '${resp.fixedCount ?? 0} fixas + ${resp.parcelaCount ?? 0} parcelas';
          // Linha removida do template é configuração apagada: silenciar seria
          // o usuário descobrir pela ausência, na fatura seguinte.
          final encerradas = resp.fixedRemoved ?? 0;
          if (encerradas > 0) {
            successMsg = '$successMsg · $encerradas '
                '${encerradas == 1 ? "fixa encerrada" : "fixas encerradas"} '
                '(última parcela)';
          }
        } else {
          switch (resp.error) {
            case 'invoice_already_exists':
              errorMsg = 'Fatura ${resp.invoiceClosing ?? closing} já existe';
              break;
            case 'fixed_expenses_failed':
              errorMsg = 'Erro nas despesas fixas: ${resp.detail ?? ''}';
              break;
            case 'lock_timeout':
              errorMsg = 'Servidor ocupado. Tente em alguns segundos.';
              break;
            case 'unauthorized':
              errorMsg = 'Sessão expirada. Saia e entre de novo.';
              break;
            default:
              errorMsg = 'Falha ao criar fatura: ${resp.error ?? "erro desconhecido"}';
          }
        }
      } catch (e) {
        // Timeout não é prova de falha: o Apps Script continua rodando depois
        // que o cliente desiste. Em 06/11/2026 a fatura foi criada e a tela
        // disse que falhou — o usuário só descobriu reabrindo o app. Antes de
        // acusar erro, confere na planilha.
        bool? criada;
        try {
          criada = await ref.read(apiProvider).faturaFoiCriada(closing);
        } catch (_) {
          criada = null; // nem a verificação respondeu
        }
        if (criada == true) {
          ref.invalidate(monthDataProvider);
          ref.invalidate(previousMonthDataProvider);
          ref.invalidate(historicalSummaryProvider);
          ref.invalidate(lastEntriesProvider);
          successMsg = 'Fatura $closing criada — a resposta demorou mais que o '
              'esperado, confira os totais';
        } else if (criada == false) {
          errorMsg = 'Falha ao criar fatura: $e';
        } else {
          errorMsg = 'Não deu para confirmar se a fatura $closing foi criada. '
              'Atualize e confira antes de tentar de novo.';
        }
      }
      if (!mounted) return;
      setState(() => _creatingInvoice = false);
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text(successMsg ?? errorMsg ?? ''),
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
          backgroundColor: successMsg != null ? BloomColors.ink : BloomColors.bad,
        ),
      );
    }

    // Bottom padding zero (apenas safe-area). O conteúdo se estende sob a
    // bottom-nav (extendBody=true). Scroll só fica disponível quando algum
    // item — tipicamente o segundo lançamento — fica parcialmente coberto
    // pela nav. Se tudo couber acima da nav, ScrollPhysics default não
    // permite rolar.
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: BloomColors.violet,
      child: SingleChildScrollView(
        padding: EdgeInsets.only(bottom: bottomPad),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _TopAppBar(
              onRefresh: onRefresh,
              onNovaFatura: onNovaFatura,
              busy: _refreshing || _creatingInvoice,
            ),
            const SizedBox(height: 6),
            _Greeting(person: person),
            const SizedBox(height: 14),
            // Seletor acima do donut: é ele que define de quem são os números
            // do card logo abaixo.
            _PersonSelector(
              selectedPerson: person,
              julioTotal: juCur.total,
              daniTotal: daCur.total,
              onSelectPerson: (p) {
                ref.read(selectedPersonProvider.notifier).state = p;
                setState(() => _selectedSegment = null);
              },
            ),
            const SizedBox(height: 12),
            _HeroCard(
              person: person,
              buckets: cur,
              selectedIdx: _selectedSegment,
              onSelect: (i) => setState(() => _selectedSegment = i),
              loading: loading && rows.isEmpty,
            ),
            const SizedBox(height: 14),
            _ComparativeCard(
              cur: cur,
              prev: prev,
              deltas: deltas,
              hasPrev: prevAsync.hasValue && prevAsync.value != null,
              currentLabel: currentMonth ?? '',
              previousLabel: ref.watch(previousMonthProvider) ?? '',
            ),
            const SizedBox(height: 12),
            _OrigemTotalsRow(totals: origemTotals(rows)),
            const SizedBox(height: 18),
            _RecentEntriesSection(asyncLast: lastAsync),
          ],
        ),
      ),
    );
  }
}

class _TopAppBar extends ConsumerStatefulWidget {
  final Future<void> Function() onRefresh;
  final Future<void> Function() onNovaFatura;
  final bool busy;
  const _TopAppBar({
    required this.onRefresh,
    required this.onNovaFatura,
    required this.busy,
  });

  @override
  ConsumerState<_TopAppBar> createState() => _TopAppBarState();
}

class _TopAppBarState extends ConsumerState<_TopAppBar> {
  final GlobalKey _menuKey = GlobalKey();

  Future<void> _openMenu() async {
    final box = _menuKey.currentContext?.findRenderObject() as RenderBox?;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (box == null || overlay == null) return;
    final pos = box.localToGlobal(Offset.zero, ancestor: overlay);
    final menuRect = RelativeRect.fromLTRB(
      pos.dx,
      pos.dy + box.size.height + 6,
      overlay.size.width - pos.dx - box.size.width,
      0,
    );

    final selected = await showMenu<_MenuAction>(
      context: context,
      position: menuRect,
      color: Colors.white,
      surfaceTintColor: Colors.white,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: BloomColors.border, width: 1),
      ),
      items: const [
        PopupMenuItem(
          value: _MenuAction.novaFatura,
          child: _MenuRow(icon: Icons.add_circle_outline, label: 'Nova fatura'),
        ),
        PopupMenuItem(
          value: _MenuAction.refresh,
          child: _MenuRow(icon: Icons.refresh, label: 'Atualizar'),
        ),
        PopupMenuDivider(),
        PopupMenuItem(
          value: _MenuAction.despesasFixas,
          child: _MenuRow(
              icon: Icons.event_repeat_outlined, label: 'Despesas fixas'),
        ),
        PopupMenuItem(
          value: _MenuAction.settings,
          child: _MenuRow(icon: Icons.settings_outlined, label: 'Configurações'),
        ),
        PopupMenuItem(
          value: _MenuAction.logout,
          child: _MenuRow(icon: Icons.logout, label: 'Sair'),
        ),
      ],
    );
    if (selected == null || !mounted) return;
    switch (selected) {
      case _MenuAction.novaFatura:
        await widget.onNovaFatura();
        break;
      case _MenuAction.refresh:
        await widget.onRefresh();
        break;
      case _MenuAction.despesasFixas:
        if (mounted) context.push('/despesas-fixas');
        break;
      case _MenuAction.settings:
        if (mounted) context.push('/settings');
        break;
      case _MenuAction.logout:
        ref.read(authProvider.notifier).signOut();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 10, 22, 0),
      child: Row(
        children: [
          const BloomLogo(size: 32),
          const SizedBox(width: 10),
          Text(
            'Hook Finance',
            style: BloomTypography.display(
              fontSize: 16,
              letterSpacing: -0.3,
            ),
          ),
          const Spacer(),
          KeyedSubtree(
            key: _menuKey,
            child: _IconBtn(
              icon: Icons.menu,
              onTap: _openMenu,
              tooltip: 'Menu',
              busy: widget.busy,
            ),
          ),
        ],
      ),
    );
  }
}

enum _MenuAction { novaFatura, refresh, despesasFixas, settings, logout }

class _MenuRow extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MenuRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: BloomColors.ink),
        const SizedBox(width: 12),
        Text(
          label,
          style: const TextStyle(
            color: BloomColors.ink,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final FutureOr<void> Function() onTap;
  final String tooltip;
  final bool busy;
  const _IconBtn({
    required this.icon,
    required this.onTap,
    required this.tooltip,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: busy ? null : () => onTap(),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: BloomColors.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: BloomColors.border, width: 1),
            ),
            alignment: Alignment.center,
            child: busy
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: BloomColors.violet,
                    ),
                  )
                : Icon(icon, size: 16, color: BloomColors.ink),
          ),
        ),
      ),
    );
  }
}

class _Greeting extends StatelessWidget {
  final Person person;
  const _Greeting({required this.person});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 6, 22, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'Olá, ',
                  style: BloomTypography.display(
                    fontSize: 24,
                    fontWeight: FontWeight.w400,
                    letterSpacing: -0.4,
                    color: BloomColors.muted,
                    height: 1,
                  ),
                ),
                Text(
                  person.displayName,
                  style: BloomTypography.display(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
          const MonthSelector(),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  final Person person;
  final PersonBuckets buckets;
  final int? selectedIdx;
  final ValueChanged<int?> onSelect;
  final bool loading;

  const _HeroCard({
    required this.person,
    required this.buckets,
    required this.selectedIdx,
    required this.onSelect,
    required this.loading,
  });

  // Duas fatias desde 2026-10-01: Compartilhado (crédito + débito divididos) e
  // Pessoal. Donut, legenda e o card Comparação seguem a mesma ordem. Crédito e
  // Débito separados vivem nos tiles abaixo do Comparação.
  static const _summaryColors = [
    BloomColors.violet, // compartilhado
    BloomColors.mint,   // pessoal
  ];

  // Sem o bloco "TOTAL PESSOAL + valor" desde 2026-10-01: o hero virou visão de
  // proporção. Os valores absolutos estão logo abaixo, nos tiles e no
  // Comparativo. O tap numa fatia segue destacando o arco e apagando as outras.
  Widget _buildSummary({
    required List<DonutBucket> donutBuckets,
    required List<Color> colors,
  }) {
    final sel = selectedIdx;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < donutBuckets.length; i++)
          _BucketLine(
            color: colors[i],
            label: donutBuckets[i].label,
            pct: donutBuckets[i].pct,
            dim: sel != null && sel != i,
            onTap: () => onSelect(sel == i ? null : i),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final donutBuckets = [
      DonutBucket(
        label: 'Compartilhado',
        value: buckets.compartilhado,
        pct:
            buckets.total == 0 ? 0 : buckets.compartilhado / buckets.total * 100,
      ),
      DonutBucket(
        label: 'Pessoal',
        value: buckets.pessoal,
        pct: buckets.total == 0 ? 0 : buckets.pessoal / buckets.total * 100,
      ),
    ];
    const colors = _summaryColors;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: BloomCard(
        soft: true,
        padding: const EdgeInsets.all(18),
        borderRadius: BorderRadius.circular(26),
        child: loading
            ? const SizedBox(
                height: 170,
                child: Center(
                    child: CircularProgressIndicator(
                        color: BloomColors.violet)),
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  BloomDonut(
                    buckets: donutBuckets,
                    total: buckets.total,
                    person: person.displayName,
                    colors: colors,
                    selectedIdx: selectedIdx,
                    onSelect: onSelect,
                    size: 140,
                    stroke: 15,
                  ),
                  const SizedBox(width: 16),
                  // IntrinsicWidth deixa a legenda com a largura do seu item
                  // mais largo, em vez de esticar até a borda do card: antes o
                  // rótulo ficava na esquerda e o percentual na direita, com um
                  // vão enorme no meio. Centrada no espaço que sobra do donut.
                  Expanded(
                    child: Center(
                      child: IntrinsicWidth(
                        child: _buildSummary(
                          donutBuckets: donutBuckets,
                          colors: colors,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _BucketLine extends StatelessWidget {
  final Color color;
  final String label;
  final double pct;
  final bool dim;
  final VoidCallback onTap;

  const _BucketLine({
    required this.color,
    required this.label,
    required this.pct,
    required this.dim,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: dim ? 0.45 : 1.0,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration:
                    BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: BloomTypography.geist(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w500,
                    color: BloomColors.ink,
                  ),
                ),
              ),
              // Respiro mínimo: com IntrinsicWidth o Expanded acima encosta o
              // percentual no rótulo mais longo.
              const SizedBox(width: 22),
              Text(
                '${pct.toStringAsFixed(0)}%',
                style: BloomTypography.mono(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: BloomColors.inkSoft,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PersonSelector extends StatelessWidget {
  final Person selectedPerson;
  final double julioTotal;
  final double daniTotal;
  final ValueChanged<Person> onSelectPerson;

  const _PersonSelector({
    required this.selectedPerson,
    required this.julioTotal,
    required this.daniTotal,
    required this.onSelectPerson,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Row(
        children: [
          Expanded(
            child: _PersonTile(
              person: Person.julio,
              total: julioTotal,
              selected: selectedPerson == Person.julio,
              onTap: () => onSelectPerson(Person.julio),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _PersonTile(
              person: Person.dani,
              total: daniTotal,
              selected: selectedPerson == Person.dani,
              onTap: () => onSelectPerson(Person.dani),
            ),
          ),
        ],
      ),
    );
  }
}

/// Os dois totais por origem, logo abaixo do Comparação. Mesma casca dos tiles
/// de pessoa — e, de propósito, a mesma largura: os dois somados são o total do
/// Júlio mais o da Dani, que estão nos tiles de cima.
class _OrigemTotalsRow extends StatelessWidget {
  final OrigemTotals totals;

  const _OrigemTotalsRow({required this.totals});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Row(
        children: [
          Expanded(
            child: _SummaryTile(
              avatarColor: BloomColors.violet,
              avatar: const Icon(Icons.credit_card,
                  size: 16, color: Colors.white),
              label: 'Total Crédito',
              total: totals.credito,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _SummaryTile(
              avatarColor: BloomColors.sky,
              avatar: const Icon(Icons.account_balance_outlined,
                  size: 16, color: Colors.white),
              label: 'Total Débito',
              total: totals.debito,
            ),
          ),
        ],
      ),
    );
  }
}

class _PersonTile extends StatelessWidget {
  final Person person;
  final double total;
  final bool selected;
  final VoidCallback onTap;

  const _PersonTile({
    required this.person,
    required this.total,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _SummaryTile(
      avatarColor: BloomColors.forPerson(person),
      avatar: Text(
        person == Person.julio ? 'J' : 'D',
        style: BloomTypography.display(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          height: 1,
        ),
      ),
      label: person.displayName,
      total: total,
      selected: selected,
      onTap: onTap,
    );
  }
}

/// Casca comum dos tiles do topo da Início: o seletor de pessoa e os totais por
/// origem. Existe para que os quatro tenham o mesmo tamanho sem copiar paddings
/// — foi o pedido explícito do usuário em 2026-10-01.
class _SummaryTile extends StatelessWidget {
  final Color avatarColor;
  final Widget avatar;
  final String label;
  final double total;
  final bool selected;
  final VoidCallback? onTap;

  const _SummaryTile({
    required this.avatarColor,
    required this.avatar,
    required this.label,
    required this.total,
    this.selected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Colors.white : BloomColors.ink;
    final fgMuted =
        selected ? Colors.white.withValues(alpha: 0.65) : BloomColors.muted;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: selected ? BloomColors.ink : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: selected
                ? null
                : Border.all(color: BloomColors.border, width: 1),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: BloomColors.ink.withValues(alpha: 0.18),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: avatarColor,
                  shape: BoxShape.circle,
                ),
                child: avatar,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: BloomTypography.geist(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: fg,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'R\$ ${formatMoney(total)}',
                        maxLines: 1,
                        style: BloomTypography.mono(
                          fontSize: 11,
                          color: fgMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ComparativeCard extends ConsumerWidget {
  final PersonBuckets cur;
  final PersonBuckets prev;
  final BucketDeltas deltas;
  final bool hasPrev;
  final String currentLabel;
  final String previousLabel;

  const _ComparativeCard({
    required this.cur,
    required this.prev,
    required this.deltas,
    required this.hasPrev,
    required this.currentLabel,
    required this.previousLabel,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cols = [
      _Col(
        label: 'Compartilhado',
        color: BloomColors.violet,
        value: cur.compartilhado,
        delta: deltas.compartilhado,
        // Aba Categoria **sem** tile de origem marcado: como o agrupamento
        // cobre as duas origens, o COMPARTILHADO / 2 de lá é Σ valor/2 de todas
        // as linhas Compartilhado — a mesma conta desta coluna. Marcar uma
        // origem mostraria só um pedaço do número clicado.
        onTap: () {
          ref.read(compartOrigemFilterProvider.notifier).state = null;
          ref.read(activeTabProvider.notifier).state = BloomTab.compart;
        },
      ),
      _Col(
        label: 'Pessoal',
        color: BloomColors.mint,
        value: cur.pessoal,
        delta: deltas.pessoal,
        onTap: () => context.push(
            '/detalhe?person=${ref.read(selectedPersonProvider).name.toLowerCase()}'),
      ),
    ];

    final curLabelLong = monthYearLong(currentLabel);
    final prevLabelLong = monthYearLong(previousLabel);
    final subtitle = hasPrev
        ? '$curLabelLong vs $prevLabelLong'
        : curLabelLong;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(
                  'Comparação',
                  style: BloomTypography.display(fontSize: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          BloomCard(
            padding: const EdgeInsets.all(14),
            borderRadius: BorderRadius.circular(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  subtitle,
                  style: BloomTypography.kicker(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            const SizedBox(height: 10),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < cols.length; i++) ...[
                    if (i > 0)
                      const VerticalDivider(
                        width: 1,
                        color: BloomColors.divider,
                      ),
                    Expanded(child: cols[i]),
                  ],
                ],
              ),
            ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Col extends StatelessWidget {
  final String label;
  final Color color;
  final double value;
  final double? delta;
  final VoidCallback? onTap;

  const _Col({
    required this.label,
    required this.color,
    required this.value,
    required this.delta,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        label.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: BloomTypography.kicker(),
                      ),
                    ),
                    if (onTap != null) ...[
                      const SizedBox(width: 2),
                      const Icon(
                        Icons.chevron_right,
                        size: 13,
                        color: BloomColors.violet,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              'R\$ ${formatMoney(value)}',
              maxLines: 1,
              style: BloomTypography.display(
                  fontSize: 15, letterSpacing: -0.3),
            ),
          ),
          const SizedBox(height: 5),
          if (delta != null)
            _DeltaBadge(value: delta!)
          else
            Text(
              '—',
              style: BloomTypography.mono(
                  fontSize: 9.5, color: BloomColors.muted),
            ),
        ],
      ),
    );

    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: content,
      ),
    );
  }
}

class _DeltaBadge extends StatelessWidget {
  final double value;
  const _DeltaBadge({required this.value});

  @override
  Widget build(BuildContext context) {
    final up = value > 0;
    final tone = up ? BloomColors.bad : BloomColors.good;
    final symbol = up ? '↗' : '↘';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.094),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$symbol ${value.abs().toStringAsFixed(1).replaceAll('.', ',')}%',
        style: BloomTypography.mono(
          fontSize: 9.5,
          fontWeight: FontWeight.w600,
          color: tone,
        ),
      ),
    );
  }
}


class _RecentEntriesSection extends ConsumerWidget {
  final AsyncValue<LastEntriesResponse> asyncLast;
  const _RecentEntriesSection({required this.asyncLast});

  Future<void> _editar(
      BuildContext context, WidgetRef ref, Entry entry) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => EditDialog(
        entry: entry,
        rowsForCategoriaSuggestions:
            ref.read(monthDataProvider(ref.read(currentMonthProvider)))
                    .value
                    ?.rows ??
                const <ExpenseRow>[],
        api: ref.read(apiProvider),
      ),
    );
    if (saved == true) {
      ref.invalidate(monthDataProvider);
      ref.invalidate(previousMonthDataProvider);
      ref.invalidate(historicalSummaryProvider);
      ref.invalidate(lastEntriesProvider);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = asyncLast.value?.entries ?? const <Entry>[];
    final shown = entries.take(3).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(
                  'Últimos lançamentos',
                  style: BloomTypography.display(fontSize: 14),
                ),
              ),
              InkWell(
                onTap: () => ref
                    .read(activeTabProvider.notifier)
                    .state = BloomTab.lancamento,
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Text(
                    'Ver mais →',
                    style: BloomTypography.geist(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: BloomColors.violet,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          BloomCard(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            borderRadius: BorderRadius.circular(18),
            child: shown.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Center(
                      child: Text(
                        'Sem lançamentos.',
                        style: BloomTypography.geist(
                          fontSize: 12,
                          color: BloomColors.muted,
                        ),
                      ),
                    ),
                  )
                : Column(
                    children: [
                      for (var i = 0; i < shown.length; i++)
                        RecentEntryRow(
                          entry: shown[i],
                          showDivider: i > 0,
                          // Sem row válido (backend antigo) o save falharia com
                          // invalid_row — mesma guarda das outras listas.
                          onTap: shown[i].row >= 2
                              ? () => _editar(context, ref, shown[i])
                              : null,
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
