// Spec: docs/specs/pages/acerto.md
// Acerto (Bloom) — hero gradient + selector D/J + 1 tabela ativa (Dani default).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/format/money.dart';
import '../../core/rules/diff_calculation.dart';
import '../../core/rules/split_for_person.dart';
import '../../core/origem.dart';
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

    // Total Pessoal da Dani — mesmo cálculo da tabela em _PersonAcertoCard:
    // cartao(compart) + cartao(pessoal) + pix(acerto=='Sim'). Diferente do
    // bucketsForPerson.total porque este último inclui TODAS as Pix.
    final daniCartaoCompart = rows
        .where((r) => r.origem == kOrigemCredito && r.rateio == 'Metade')
        .fold<double>(0, (s, r) => s + splitForPerson(r, Person.dani));
    final daniCartaoPessoal = rows
        .where((r) => r.origem == kOrigemCredito && r.rateio == Person.dani.name)
        .fold<double>(0, (s, r) => s + splitForPerson(r, Person.dani));
    final daniPixAcerto = rows
        .where((r) =>
            r.origem == kOrigemDebito &&
            r.rateio == Person.dani.name &&
            r.acerto == 'Sim')
        .fold<double>(0, (s, r) => s + r.valor);
    final daniTotalPessoal =
        daniCartaoCompart + daniCartaoPessoal + daniPixAcerto;

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
                  child: CircularProgressIndicator(
                      color: BloomColors.violet),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: _PersonAcertoCard(
                  person: _selected,
                  rows: rows,
                  onSwap: () => setState(() {
                    _selected =
                        _selected == Person.dani ? Person.julio : Person.dani;
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

class _PersonAcertoCard extends ConsumerWidget {
  final Person person;
  final List<ExpenseRow> rows;
  final VoidCallback onSwap;

  const _PersonAcertoCard({
    required this.person,
    required this.rows,
    required this.onSwap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final personColor = BloomColors.forPerson(person);
    final isJulio = person == Person.julio;
    final pixExpanded = ref.watch(acertoPixJulioProvider) && isJulio;

    final cartao = rows.where((r) => r.origem == kOrigemCredito);
    final cartaoCompart = cartao
        .where((r) => r.rateio == 'Metade')
        .fold<double>(0, (s, r) => s + splitForPerson(r, person));
    final cartaoPessoal = cartao
        .where((r) => r.rateio == person.name)
        .fold<double>(0, (s, r) => s + splitForPerson(r, person));

    // Para Júlio com toggle expandido, mostra todas as Pix dele (sem filtro
    // por `acerto == 'Sim'`). Mantém o comportamento legado do PWA.
    final pixRows = rows
        .where((r) =>
            r.origem == kOrigemDebito &&
            r.rateio == person.name &&
            (pixExpanded || r.acerto == 'Sim'))
        .toList();
    final pixSubtotal =
        pixRows.fold<double>(0, (s, r) => s + r.valor);
    final total = cartaoCompart + cartaoPessoal + pixSubtotal;

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
                      horizontal: 10, vertical: 4),
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
                          color:
                              personColor.withValues(alpha: 0.85),
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
                    child: Text('DESPESA',
                        style: BloomTypography.kicker())),
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
          // Cartão rows
          _DataRow(
            label: 'Crédito (compartilhado)',
            value: cartaoCompart,
            total: total,
          ),
          _DataRow(
            label: 'Crédito (pessoal)',
            value: cartaoPessoal,
            total: total,
          ),
          // Linha "Débito" — mesma identidade visual de Crédito (compart/pessoal),
          // mostrando o subtotal de débito. Para Júlio, clicável (toggle expandir).
          InkWell(
            onTap: isJulio
                ? () => ref
                    .read(acertoPixJulioProvider.notifier)
                    .state = !pixExpanded
                : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 18, vertical: 9),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Text(
                          'Débito',
                          style: BloomTypography.geist(
                            fontSize: 12.5,
                            color: BloomColors.ink,
                          ),
                        ),
                        if (isJulio) ...[
                          const SizedBox(width: 2),
                          Icon(
                            pixExpanded
                                ? Icons.expand_less
                                : Icons.expand_more,
                            size: 16,
                            color: BloomColors.muted,
                          ),
                        ],
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 80,
                    child: Text(
                      formatMoney(pixSubtotal),
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
                      '${(total == 0 ? 0 : pixSubtotal / total * 100).toStringAsFixed(1).replaceAll('.', ',')}%',
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
          if (pixRows.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(38, 6, 18, 12),
              child: Text(
                'Sem Pix de acerto.',
                style: BloomTypography.geist(
                  fontSize: 12,
                  color: BloomColors.muted,
                ),
              ),
            )
          else
            for (final r in pixRows)
              _DataRow(
                label: r.descricao.isEmpty ? '—' : r.descricao,
                value: r.valor,
                total: pixSubtotal,
                small: true,
                indent: 20,
              ),
          const SizedBox(height: 6),
          // Total Pessoal
          Container(
            decoration: const BoxDecoration(
              color: BloomColors.bg3,
              border: Border(
                top: BorderSide(color: BloomColors.ink, width: 2),
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(22),
                bottomRight: Radius.circular(22),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 18, vertical: 12),
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
          18 + indent, small ? 5 : 9, 18, small ? 5 : 9),
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
