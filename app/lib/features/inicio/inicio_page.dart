// Spec: docs/specs/pages/inicio.md
// Visão pessoal — donut + buckets + comparativo + recentes.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/format/money.dart';
import '../../core/origem.dart';
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
    final lastAsync = ref.watch(lastEntriesProvider(3));

    final rows = monthAsync.value?.rows ?? const <ExpenseRow>[];
    final cur = bucketsForPerson(rows, person);

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
            const SizedBox(height: 10),
            // Um card só: seletor de pessoa, total do mês com o donut e o
            // atalho para as despesas pessoais dela.
            _HeroCard(
              person: person,
              buckets: cur,
              selectedIdx: _selectedSegment,
              onSelect: (i) => setState(() => _selectedSegment = i),
              onSelectPerson: (p) {
                ref.read(selectedPersonProvider.notifier).state = p;
                setState(() => _selectedSegment = null);
              },
              loading: loading && rows.isEmpty,
            ),
            const SizedBox(height: 14),
            _TotaisSection(
              buckets: cur,
              totalCredito: origemTotals(rows).credito,
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
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      child: Row(
        children: [
          const BloomLogo(size: 36),
          const SizedBox(width: 10),
          // Expanded sem Spacer depois: os dois têm flex 1 e dividiriam a
          // sobra, truncando o título ("Hook Fina...") com a pílula de mês já
          // no seu tamanho final. O título fica com tudo que sobrar.
          Expanded(
            child: Text(
              'Hook Finance',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: BloomTypography.display(
                fontSize: 17,
                letterSpacing: -0.3,
              ),
            ),
          ),
          const SizedBox(width: 8),
          const MonthSelector(abbrev: true),
          const SizedBox(width: 8),
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
/// Card principal: seletor de pessoa, total do mês com donut e o atalho para
/// as despesas pessoais. Spec: docs/specs/pages/inicio.md
class _HeroCard extends ConsumerWidget {
  final Person person;
  final PersonBuckets buckets;
  final int? selectedIdx;
  final ValueChanged<int?> onSelect;
  final ValueChanged<Person> onSelectPerson;
  final bool loading;

  const _HeroCard({
    required this.person,
    required this.buckets,
    required this.selectedIdx,
    required this.onSelect,
    required this.onSelectPerson,
    required this.loading,
  });

  // Duas fatias desde 2026-10-01: Compartilhado (crédito + débito divididos) e
  // Pessoal. Donut e legenda leem desta lista — quando o donut tinha a sua por
  // dentro, reordenar as fatias pintou cada uma de uma cor errada.
  static const _cores = [BloomColors.violet, BloomColors.mint];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: BloomCard(
        padding: const EdgeInsets.all(8),
        borderRadius: BorderRadius.circular(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _PersonSwitch(selected: person, onSelect: onSelectPerson),
            const SizedBox(height: 16),
            if (loading)
              const SizedBox(
                height: 120,
                child: Center(
                  child: CircularProgressIndicator(color: BloomColors.violet),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Gastos de ${person.displayName} no mês',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: BloomTypography.geist(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w500,
                              color: BloomColors.muted,
                            ),
                          ),
                          const SizedBox(height: 6),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  'R\$ ',
                                  style: BloomTypography.display(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600,
                                    color: BloomColors.muted,
                                  ),
                                ),
                                Text(
                                  formatMoney(buckets.total),
                                  maxLines: 1,
                                  style: BloomTypography.display(
                                    fontSize: 32,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.8,
                                    height: 1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          for (var i = 0; i < donutBuckets.length; i++)
                            _LegendLine(
                              color: _cores[i],
                              label: donutBuckets[i].label,
                              pct: donutBuckets[i].pct,
                              dim: selectedIdx != null && selectedIdx != i,
                              onTap: () =>
                                  onSelect(selectedIdx == i ? null : i),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    BloomDonut(
                      buckets: donutBuckets,
                      total: buckets.total,
                      person: '',
                      colors: _cores,
                      selectedIdx: selectedIdx,
                      onSelect: onSelect,
                      size: 92,
                      stroke: 13,
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 14),
            _AtalhoPessoal(
              valor: buckets.pessoalCredito,
              onTap: () => context.push(
                  '/detalhe?person=${person.name.toLowerCase()}'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Seletor de pessoa em trilho único (segmented control). Substituiu dois tiles
/// soltos que repetiam o total — o total agora é um só, logo abaixo, e é da
/// pessoa marcada aqui.
class _PersonSwitch extends StatelessWidget {
  final Person selected;
  final ValueChanged<Person> onSelect;

  const _PersonSwitch({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: BloomColors.track,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          for (final p in Person.values) ...[
            if (p != Person.values.first) const SizedBox(width: 4),
            Expanded(
              child: _PersonSwitchItem(
                person: p,
                active: selected == p,
                onTap: () => onSelect(p),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PersonSwitchItem extends StatelessWidget {
  final Person person;
  final bool active;
  final VoidCallback onTap;

  const _PersonSwitchItem({
    required this.person,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? BloomColors.card : Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      elevation: active ? 1.5 : 0,
      shadowColor: BloomColors.ink.withValues(alpha: 0.18),
      // Sem isto o Material 3 mistura `surfaceTint` na cor quando há elevação:
      // a aba marcada saía cinza-lilás, mais escura que a não-marcada.
      surfaceTintColor: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: SizedBox(
          height: 44,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: BloomColors.forPerson(person),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  person == Person.julio ? 'J' : 'D',
                  style: BloomTypography.display(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    height: 1,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  person.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: BloomTypography.geist(
                    fontSize: 14.5,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                    color: active ? BloomColors.ink : BloomColors.muted,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LegendLine extends StatelessWidget {
  final Color color;
  final String label;
  final double pct;
  final bool dim;
  final VoidCallback onTap;

  const _LegendLine({
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
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: BloomTypography.geist(
                    fontSize: 12.5,
                    color: BloomColors.muted,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '${pct.toStringAsFixed(0)}%',
                style: BloomTypography.geist(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: BloomColors.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Atalho para as despesas pessoais da pessoa, dentro do card.
class _AtalhoPessoal extends StatelessWidget {
  final double valor;
  final VoidCallback onTap;

  const _AtalhoPessoal({required this.valor, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: BloomColors.soft,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              const _IconChip(
                icon: Icons.credit_card,
                bg: BloomColors.violetTint,
                fg: BloomColors.violetDeep,
                size: 40,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Crédito (pessoal)',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: BloomTypography.geist(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'R\$ ${formatMoney(valor)}',
                style: BloomTypography.mono(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: BloomColors.inkSoft,
                ),
              ),
              const SizedBox(width: 2),
              const Icon(Icons.chevron_right,
                  size: 18, color: BloomColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _IconChip extends StatelessWidget {
  final IconData icon;
  final Color bg;
  final Color fg;
  final double size;

  const _IconChip({
    required this.icon,
    required this.bg,
    required this.fg,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      child: Icon(icon, size: size * 0.5, color: fg),
    );
  }
}

/// Total de crédito do casal + os quatro quadrantes da pessoa selecionada.
///
/// Os quatro somam o total do card acima: `(Crédito | Débito) ×
/// (compartilhado | pessoal)` particiona tudo que toca a pessoa.
class _TotaisSection extends ConsumerWidget {
  final PersonBuckets buckets;
  final double totalCredito;

  const _TotaisSection({required this.buckets, required this.totalCredito});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void irParaCategoria(String origem) {
      ref.read(compartOrigemFilterProvider.notifier).state = origem;
      ref.read(activeTabProvider.notifier).state = BloomTab.compart;
    }

    void irParaPessoal() => context.push(
        '/detalhe?person=${ref.read(selectedPersonProvider).name.toLowerCase()}');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BloomCard(
            padding: const EdgeInsets.fromLTRB(12, 12, 16, 12),
            borderRadius: BorderRadius.circular(20),
            child: Row(
              children: [
                const _IconChip(
                  icon: Icons.credit_card,
                  bg: BloomColors.track,
                  fg: BloomColors.ink,
                  size: 40,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Total cartão de crédito',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: BloomTypography.geist(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'R\$ ${formatMoney(totalCredito)}',
                  style: BloomTypography.mono(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _QuadranteTile(
                  origem: 'Crédito',
                  escopo: 'compartilhado',
                  valor: buckets.credito,
                  icon: Icons.credit_card,
                  bg: BloomColors.violetTint,
                  fg: BloomColors.violetDeep,
                  onTap: () => irParaCategoria(kOrigemCredito),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _QuadranteTile(
                  origem: 'Débito',
                  escopo: 'compartilhado',
                  valor: buckets.debito,
                  icon: Icons.account_balance_outlined,
                  bg: BloomColors.violetTint,
                  fg: BloomColors.violetDeep,
                  onTap: () => irParaCategoria(kOrigemDebito),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _QuadranteTile(
                  origem: 'Crédito',
                  escopo: 'pessoal',
                  valor: buckets.pessoalCredito,
                  icon: Icons.credit_card,
                  bg: BloomColors.mintTint,
                  fg: BloomColors.mintDeep,
                  onTap: irParaPessoal,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _QuadranteTile(
                  origem: 'Débito',
                  escopo: 'pessoal',
                  valor: buckets.pessoalDebito,
                  icon: Icons.account_balance_outlined,
                  bg: BloomColors.mintTint,
                  fg: BloomColors.mintDeep,
                  onTap: irParaPessoal,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuadranteTile extends StatelessWidget {
  final String origem;
  final String escopo;
  final double valor;
  final IconData icon;
  final Color bg;
  final Color fg;
  final VoidCallback onTap;

  const _QuadranteTile({
    required this.origem,
    required this.escopo,
    required this.valor,
    required this.icon,
    required this.bg,
    required this.fg,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return BloomCard(
      padding: EdgeInsets.zero,
      borderRadius: BorderRadius.circular(20),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                _IconChip(icon: icon, bg: bg, fg: fg, size: 36),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        origem,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: BloomTypography.geist(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        escopo,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: BloomTypography.geist(
                          fontSize: 11.5,
                          color: BloomColors.muted,
                        ),
                      ),
                      const SizedBox(height: 4),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'R\$ ${formatMoney(valor)}',
                          maxLines: 1,
                          style: BloomTypography.mono(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: BloomColors.inkSoft,
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
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Últimos lançamentos',
                  style: BloomTypography.display(
                    fontSize: 17,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              InkWell(
                onTap: () => ref
                    .read(activeTabProvider.notifier)
                    .state = BloomTab.lancamento,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Ver todos',
                        style: BloomTypography.geist(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: BloomColors.violetDeep,
                        ),
                      ),
                      const SizedBox(width: 3),
                      const Icon(Icons.arrow_forward,
                          size: 14, color: BloomColors.violetDeep),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          BloomCard(
            padding: const EdgeInsets.all(6),
            borderRadius: BorderRadius.circular(24),
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
                          spacious: true,
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
