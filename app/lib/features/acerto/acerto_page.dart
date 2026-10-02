// Spec: docs/specs/pages/acerto.md
// Acerto (Bloom) — hero gradient + selector D/J + 1 tabela ativa (Dani default).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/format/money.dart';
import '../../core/rules/diff_calculation.dart';
import '../../core/rules/acerto_total.dart';
import '../../core/rules/split_for_person.dart';
import '../../core/types.dart';
import '../../state/data_providers.dart';
import '../../theme/bloom_colors.dart';
import '../../theme/bloom_typography.dart';
import '../../widgets/bloom/bloom_card.dart';
import '../../widgets/bloom/month_selector.dart';
import '../../widgets/bloom/screen_header.dart';

class AcertoPage extends ConsumerStatefulWidget {
  const AcertoPage({super.key});

  @override
  ConsumerState<AcertoPage> createState() => _AcertoPageState();
}

class _AcertoPageState extends ConsumerState<AcertoPage> {
  Person _selected = Person.dani;

  @override
  Widget build(BuildContext context) {
    final currentMonth = ref.watch(currentMonthProvider);
    final monthAsync = ref.watch(monthDataProvider(currentMonth));
    final rows = monthAsync.value?.rows ?? const <ExpenseRow>[];
    final loading = monthAsync.isLoading && !monthAsync.hasValue;

    // Mesma função que o card usa no "Total Pessoal" — este número e aquele são
    // o mesmo valor, e já divergiram por estarem calculados em dois lugares.
    final daniTotalPessoal = acertoBreakdown(rows, Person.dani).total;

    Future<void> onRefresh() async {
      ref.invalidate(monthDataProvider);
      try {
        await ref.read(monthDataProvider(currentMonth).future);
      } catch (_) {}
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: BloomColors.violet,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.only(
          bottom: 70 + MediaQuery.of(context).padding.bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const ScreenHeader(
              kicker: 'Acerto',
              title: 'Acerto Final',
              trailing: MonthSelector(),
            ),
            const SizedBox(height: 12),
            _Hero(total: daniTotalPessoal),
            const SizedBox(height: 14),
            if (loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: CircularProgressIndicator(color: BloomColors.violet),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: _PersonAcertoCard(
                  person: _selected,
                  rows: rows,
                  onSwap: () => setState(() {
                    _selected = _selected == Person.dani
                        ? Person.julio
                        : Person.dani;
                  }),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  final double total;

  const _Hero({required this.total});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [BloomColors.violet, BloomColors.sky],
          ),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: BloomColors.violet.withValues(alpha: 0.30),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'DANI TRANSFERE PARA JÚLIO',
              style: BloomTypography.geist(
                fontSize: 11,
                color: Colors.white.withValues(alpha: 0.85),
                letterSpacing: 0.4,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                'R\$ ${formatMoney(total)}',
                maxLines: 1,
                style: BloomTypography.display(
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  height: 1.05,
                  letterSpacing: -0.6,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PersonAcertoCard extends ConsumerStatefulWidget {
  final Person person;
  final List<ExpenseRow> rows;
  final VoidCallback onSwap;

  const _PersonAcertoCard({
    required this.person,
    required this.rows,
    required this.onSwap,
  });

  @override
  ConsumerState<_PersonAcertoCard> createState() => _PersonAcertoCardState();
}

class _PersonAcertoCardState extends ConsumerState<_PersonAcertoCard> {
  // Uma expansão por linha agrupada, para as duas pessoas. Abertas por padrão,
  // que é como a tela sempre mostrou os filhos.
  bool _reembolsosAberto = true;
  bool _creditoCompartAberto = true;
  bool _creditoPessoalAberto = true;
  bool _compartAberto = true;
  bool _pessoalAberto = true;

  @override
  Widget build(BuildContext context) {
    final person = widget.person;
    final rows = widget.rows;
    final onSwap = widget.onSwap;
    final personColor = BloomColors.forPerson(person);

    // Spec: docs/specs/cards/acerto-card.md
    final b = acertoBreakdown(rows, person);
    final linhas = acertoDebitoRows(rows, person);
    final cartaoCompart = b.creditoCompart;
    final cartaoPessoal = b.creditoPessoal;
    final debitoCompart = b.debitoCompart;
    final debitoPessoal = b.debitoPessoal;
    final total = b.total;

    // Filhos de cada grupo já como (rótulo, valor): no débito cada filho é um
    // lançamento; no crédito compartilhado é uma categoria, porque a fatura
    // dividida inteira daria dezenas de linhas.
    List<_Filho> deLancamentos(
      List<ExpenseRow> rows, {
      required bool metade,
    }) =>
        [
          for (final r in rows)
            _Filho(
              label: r.descricao.isEmpty ? '—' : r.descricao,
              valor: metade ? splitForPerson(r, person) : r.valor,
            ),
        ];

    List<_Filho> porCategoria({required bool compartilhado}) => [
          for (final c in acertoCreditoCategorias(rows, person,
              compartilhado: compartilhado))
            _Filho(label: c.categoria, valor: c.valor),
        ];

    final diff = diffCalculation(rows, person).abs();

    return BloomCard(
      padding: EdgeInsets.zero,
      borderRadius: BorderRadius.circular(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: const Alignment(-0.95, 0),
                end: const Alignment(0.95, 0),
                colors: [
                  personColor.withValues(alpha: 0.094),
                  personColor.withValues(alpha: 0.024),
                ],
              ),
              border: const Border(
                bottom: BorderSide(color: BloomColors.divider, width: 1),
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(22),
                topRight: Radius.circular(22),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: personColor,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    person == Person.julio ? 'J' : 'D',
                    style: BloomTypography.display(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      height: 1,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  person.displayName,
                  style: BloomTypography.display(
                    fontSize: 17,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(width: 8),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onSwap,
                    borderRadius: BorderRadius.circular(999),
                    child: Tooltip(
                      message: 'Trocar pessoa',
                      child: Container(
                        width: 26,
                        height: 26,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: personColor.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: personColor.withValues(alpha: 0.30),
                            width: 1,
                          ),
                        ),
                        child: Icon(
                          Icons.swap_horiz,
                          size: 16,
                          color: personColor,
                        ),
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: personColor.withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Diferença ',
                        style: BloomTypography.mono(
                          fontSize: 10.5,
                          color: personColor.withValues(alpha: 0.85),
                        ),
                      ),
                      Text(
                        'R\$ ${formatMoney(diff)}',
                        style: BloomTypography.mono(
                          fontSize: 10.5,
                          color: personColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Column headers
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text('DESPESA', style: BloomTypography.kicker()),
                ),
                SizedBox(
                  width: 80,
                  child: Text(
                    'VALOR',
                    textAlign: TextAlign.right,
                    style: BloomTypography.kicker(),
                  ),
                ),
                SizedBox(
                  width: 50,
                  child: Text(
                    '%',
                    textAlign: TextAlign.right,
                    style: BloomTypography.kicker(),
                  ),
                ),
              ],
            ),
          ),
          _Grupo(
            label: 'Reembolsos',
            subtotal: b.reembolso,
            total: total,
            filhos: deLancamentos(acertoReembolsos(rows, person), metade: true),
            aberto: _reembolsosAberto,
            onToggle: () =>
                setState(() => _reembolsosAberto = !_reembolsosAberto),
            vazio:
                'Nada marcado para ${person.other.displayName} reembolsar.',
          ),
          _SubtotalRow(
              label: 'Subtotal reembolsos', value: b.reembolso, total: total),
          // Cartão rows
          _Grupo(
            label: 'Crédito (compartilhado)',
            subtotal: cartaoCompart,
            total: total,
            filhos: porCategoria(compartilhado: true),
            aberto: _creditoCompartAberto,
            onToggle: () => setState(
                () => _creditoCompartAberto = !_creditoCompartAberto),
            vazio: 'Sem crédito dividido neste mês.',
          ),
          _Grupo(
            label: 'Crédito (pessoal)',
            subtotal: cartaoPessoal,
            total: total,
            filhos: porCategoria(compartilhado: false),
            aberto: _creditoPessoalAberto,
            onToggle: () => setState(
                () => _creditoPessoalAberto = !_creditoPessoalAberto),
            vazio: 'Sem crédito pessoal neste mês.',
          ),
          _SubtotalRow(label: 'Subtotal crédito', value: b.credito, total: total),
          _Grupo(
            label: 'Débito (compartilhado)',
            subtotal: debitoCompart,
            total: total,
            filhos: deLancamentos(linhas.compart, metade: true),
            aberto: _compartAberto,
            onToggle: () => setState(() => _compartAberto = !_compartAberto),
            vazio: 'Sem débito dividido neste mês.',
          ),
          _Grupo(
            label: 'Débito (pessoal)',
            subtotal: debitoPessoal,
            total: total,
            filhos: deLancamentos(linhas.pessoal, metade: false),
            aberto: _pessoalAberto,
            onToggle: () => setState(() => _pessoalAberto = !_pessoalAberto),
            vazio: 'Sem débito pessoal neste mês.',
          ),
          _SubtotalRow(label: 'Subtotal débito', value: b.debito, total: total),
          const SizedBox(height: 6),
          // Total Pessoal
          Container(
            decoration: const BoxDecoration(
              color: BloomColors.bg3,
              border: Border(top: BorderSide(color: BloomColors.ink, width: 2)),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(22),
                bottomRight: Radius.circular(22),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Total Pessoal',
                      style: BloomTypography.display(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 80,
                    child: Text(
                      formatMoney(total),
                      textAlign: TextAlign.right,
                      style: BloomTypography.mono(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 50,
                    child: Text(
                      '100%',
                      textAlign: TextAlign.right,
                      style: BloomTypography.mono(
                        fontSize: 11,
                        color: BloomColors.muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Um filho de uma linha agrupada: um lançamento ou uma categoria.
class _Filho {
  final String label;
  final double valor;

  const _Filho({required this.label, required this.valor});
}

/// Linha agrupada do acerto, com expandir/recolher e o que a compõe. Quatro por
/// card: o crédito dividido (filhos = categorias), o débito dividido e os dois
/// débitos da pessoa (filhos = lançamentos).
///
/// Até 2026-10-01 havia uma linha de débito só, e o toggle (exclusivo do Júlio)
/// mudava a COMPOSIÇÃO — incluía lançamentos fora do acerto e o subtotal mudava
/// junto. Agora expandir só mostra ou esconde; o subtotal é sempre o que entra
/// no acerto, e os filhos sempre o somam. Spec: docs/specs/pages/acerto.md
class _Grupo extends StatelessWidget {
  final String label;
  final double subtotal;
  final double total;
  final List<_Filho> filhos;
  final bool aberto;
  final VoidCallback onToggle;
  final String vazio;

  const _Grupo({
    required this.label,
    required this.subtotal,
    required this.total,
    required this.filhos,
    required this.aberto,
    required this.onToggle,
    required this.vazio,
  });

  @override
  Widget build(BuildContext context) {
    final pct = total == 0 ? 0.0 : subtotal / total * 100;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Material próprio: o InkWell depende de um ancestral Material, que aqui
        // vinha só do Scaffold do shell — o widget quebra fora dele.
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: BloomTypography.geist(
                              fontSize: 12.5,
                              color: BloomColors.ink,
                            ),
                          ),
                        ),
                        const SizedBox(width: 2),
                        Icon(
                          aberto ? Icons.expand_less : Icons.expand_more,
                          size: 16,
                          color: BloomColors.muted,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 80,
                    child: Text(
                      formatMoney(subtotal),
                      textAlign: TextAlign.right,
                      style: BloomTypography.mono(
                        fontSize: 12,
                        color: BloomColors.ink,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 50,
                    child: Text(
                      '${pct.toStringAsFixed(1).replaceAll('.', ',')}%',
                      textAlign: TextAlign.right,
                      style: BloomTypography.mono(
                        fontSize: 10.5,
                        color: BloomColors.muted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (aberto)
          if (filhos.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(38, 0, 18, 10),
              child: Text(
                vazio,
                style: BloomTypography.geist(
                  fontSize: 12,
                  color: BloomColors.muted,
                ),
              ),
            )
          else
            for (final f in filhos)
              _DataRow(
                label: f.label,
                value: f.valor,
                total: subtotal,
                small: true,
                indent: 20,
              ),
      ],
    );
  }
}

/// Fecha cada metade da tabela com a soma das suas duas linhas agrupadoras.
///
/// Faixa de fundo de ponta a ponta, mais alta que uma linha comum: é o que
/// divide a tabela em blocos à primeira vista, sem depender de um filete fino
/// que se perdia entre os filhos indentados logo acima dela.
class _SubtotalRow extends StatelessWidget {
  final String label;
  final double value;
  final double total;

  const _SubtotalRow({
    required this.label,
    required this.value,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final pct = total == 0 ? 0.0 : value / total * 100;
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: const BoxDecoration(
        color: BloomColors.track,
        border: Border(
          top: BorderSide(color: BloomColors.border, width: 1),
          bottom: BorderSide(color: BloomColors.border, width: 1),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: BloomTypography.geist(
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          SizedBox(
            width: 80,
            child: Text(
              formatMoney(value),
              textAlign: TextAlign.right,
              style: BloomTypography.mono(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          SizedBox(
            width: 50,
            child: Text(
              '${pct.toStringAsFixed(1).replaceAll('.', ',')}%',
              textAlign: TextAlign.right,
              style: BloomTypography.mono(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: BloomColors.muted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DataRow extends StatelessWidget {
  final String label;
  final double value;
  final double total;
  final bool small;
  final double indent;

  const _DataRow({
    required this.label,
    required this.value,
    required this.total,
    this.small = false,
    this.indent = 0,
  });

  @override
  Widget build(BuildContext context) {
    final pct = total == 0 ? 0.0 : (value / total) * 100;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        18 + indent,
        small ? 5 : 9,
        18,
        small ? 5 : 9,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: BloomTypography.geist(
                fontSize: small ? 12 : 12.5,
                color: small ? BloomColors.inkSoft : BloomColors.ink,
              ),
            ),
          ),
          SizedBox(
            width: 80,
            child: Text(
              formatMoney(value),
              textAlign: TextAlign.right,
              style: BloomTypography.mono(
                fontSize: small ? 11.5 : 12,
                color: small ? BloomColors.inkSoft : BloomColors.ink,
              ),
            ),
          ),
          SizedBox(
            width: 50,
            child: Text(
              '${pct.toStringAsFixed(1).replaceAll('.', ',')}%',
              textAlign: TextAlign.right,
              style: BloomTypography.mono(
                fontSize: small ? 10 : 10.5,
                color: BloomColors.muted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
