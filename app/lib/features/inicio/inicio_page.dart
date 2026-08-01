// Spec: docs/specs/pages/inicio.md
// Visão pessoal — donut + buckets + comparativo + recentes.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/format/dates.dart';
import '../../core/format/money.dart';
import '../../core/rules/bucket_deltas.dart';
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
    final lastAsync = ref.watch(lastEntriesProvider(2));

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
          ref.read(lastEntriesProvider(2).future),
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
        errorMsg = 'Falha ao criar fatura: $e';
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
            _HeroCard(
              person: person,
              buckets: cur,
              selectedIdx: _selectedSegment,
              onSelect: (i) => setState(() => _selectedSegment = i),
              loading: loading && rows.isEmpty,
            ),
            const SizedBox(height: 14),
            _SmallTiles(
              rows: rows,
              selectedPerson: person,
              julioTotal: juCur.total,
              daniTotal: daCur.total,
              onSelectPerson: (p) {
                ref.read(selectedPersonProvider.notifier).state = p;
                setState(() => _selectedSegment = null);
              },
            ),
            const SizedBox(height: 12),
            _QuickLinks(
              onPersonalTap: () => context
                  .push('/detalhe?person=${person.name.toLowerCase()}'),
              onCompartTap: () => ref
                  .read(activeTabProvider.notifier)
                  .state = BloomTab.compart,
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

enum _MenuAction { novaFatura, refresh, settings, logout }

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

  static const _summaryColors = [
    BloomColors.violet, // compart
    BloomColors.mint,   // pessoal
    BloomColors.sky,    // contas
  ];

  Widget _buildSummary({
    required List<DonutBucket> donutBuckets,
    required List<Color> colors,
  }) {
    final sel = selectedIdx;
    final kicker = sel == null
        ? 'TOTAL PESSOAL'
        : donutBuckets[sel].label.toUpperCase().replaceAll('.', '');
    final value = sel == null ? buckets.total : donutBuckets[sel].value;
    final valueColor =
        sel == null ? BloomColors.ink : _summaryColors[sel];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          kicker,
          style: BloomTypography.kicker(
            color: sel == null ? null : valueColor,
          ),
        ),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            'R\$ ${formatMoney(value)}',
            maxLines: 1,
            style: BloomTypography.display(
              fontSize: 22,
              letterSpacing: -0.5,
              color: valueColor,
            ),
          ),
        ),
        const SizedBox(height: 8),
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
        value: buckets.compart,
        pct: buckets.total == 0 ? 0 : buckets.compart / buckets.total * 100,
      ),
      DonutBucket(
        label: 'Pessoal',
        value: buckets.pessoal,
        pct: buckets.total == 0 ? 0 : buckets.pessoal / buckets.total * 100,
      ),
      DonutBucket(
        label: 'Contas',
        value: buckets.contas,
        pct: buckets.total == 0 ? 0 : buckets.contas / buckets.total * 100,
      ),
    ];
    final colors = [
      BloomColors.violet,
      BloomColors.mint,
      BloomColors.sky,
    ];

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
                    selectedIdx: selectedIdx,
                    onSelect: onSelect,
                    size: 140,
                    stroke: 15,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildSummary(
                      donutBuckets: donutBuckets,
                      colors: colors,
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
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration:
                    BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: BloomTypography.geist(
                    fontSize: 11.5,
                    color: BloomColors.inkSoft,
                  ),
                ),
              ),
              Text(
                '${pct.toStringAsFixed(0)}%',
                style: BloomTypography.mono(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SmallTiles extends StatelessWidget {
  final List<ExpenseRow> rows;
  final Person selectedPerson;
  final double julioTotal;
  final double daniTotal;
  final ValueChanged<Person> onSelectPerson;

  const _SmallTiles({
    required this.rows,
    required this.selectedPerson,
    required this.julioTotal,
    required this.daniTotal,
    required this.onSelectPerson,
  });

  @override
  Widget build(BuildContext context) {
    final totalCartao = rows
        .where((r) => r.origem == 'Cartão')
        .fold<double>(0, (s, r) => s + r.valor);
    final totalParcelado = rows.where((r) {
      final p = r.parcela;
      if (p.isEmpty) return false;
      final parts = p.split('/');
      if (parts.length != 2) return false;
      final t = int.tryParse(parts[1]) ?? 1;
      return t > 1;
    }).fold<double>(0, (s, r) => s + r.valor);

    final parceladoPct =
        totalCartao == 0 ? null : totalParcelado / totalCartao * 100;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Column(
        children: [
          Row(
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
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _Tile(label: 'Total cartão', value: totalCartao),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Tile(
                  label: 'Parcelado',
                  value: totalParcelado,
                  pct: parceladoPct,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickLinks extends StatelessWidget {
  final VoidCallback onPersonalTap;
  final VoidCallback onCompartTap;
  const _QuickLinks({
    required this.onPersonalTap,
    required this.onCompartTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Row(
        children: [
          Expanded(
            child: _LinkPill(
              icon: Icons.person_outline,
              label: 'Ver pessoal',
              onTap: onPersonalTap,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _LinkPill(
              icon: Icons.credit_card_outlined,
              label: 'Ver compartilhado',
              onTap: onCompartTap,
            ),
          ),
        ],
      ),
    );
  }
}

class _LinkPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _LinkPill({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: BloomColors.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: BloomColors.border, width: 1),
          ),
          child: Row(
            children: [
              Icon(icon, size: 14, color: BloomColors.violet),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: BloomTypography.geist(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: BloomColors.violet,
                  ),
                ),
              ),
              const Icon(
                Icons.arrow_forward,
                size: 12,
                color: BloomColors.violet,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final String label;
  final double value;
  final double? pct;
  const _Tile({required this.label, required this.value, this.pct});

  @override
  Widget build(BuildContext context) {
    return BloomCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      borderRadius: BorderRadius.circular(18),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label.toUpperCase(),
                style: BloomTypography.kicker(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              SizedBox(
                height: 24,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'R\$ ${formatMoney(value)}',
                    maxLines: 1,
                    style: BloomTypography.display(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.4,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (pct != null)
            Positioned(
              top: -2,
              right: -2,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: BloomColors.violet.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${pct!.toStringAsFixed(1).replaceAll('.', ',')}%',
                  style: BloomTypography.mono(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: BloomColors.violet,
                  ),
                ),
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
    final personColor = BloomColors.forPerson(person);
    final initial = person == Person.julio ? 'J' : 'D';
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
                  color: personColor,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  initial,
                  style: BloomTypography.display(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    height: 1,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      person.displayName,
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
        value: cur.compart,
        delta: deltas.compart,
      ),
      _Col(
        label: 'Pessoal',
        color: BloomColors.mint,
        value: cur.pessoal,
        delta: deltas.pessoal,
      ),
      _Col(
        label: 'Contas',
        color: BloomColors.sky,
        value: cur.contas,
        delta: deltas.contas,
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
              if (hasPrev)
                InkWell(
                  onTap: () => ref
                      .read(activeTabProvider.notifier)
                      .state = BloomTab.historico,
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 4, vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Ver histórico',
                          style: BloomTypography.geist(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: BloomColors.violet,
                          ),
                        ),
                        const SizedBox(width: 2),
                        const Icon(
                          Icons.arrow_forward,
                          size: 12,
                          color: BloomColors.violet,
                        ),
                      ],
                    ),
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

  const _Col({
    required this.label,
    required this.color,
    required this.value,
    required this.delta,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
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
                child: Text(
                  label.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: BloomTypography.kicker(),
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = asyncLast.value?.entries ?? const <Entry>[];
    final shown = entries.take(2).toList();

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
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
