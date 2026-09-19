// Spec: docs/specs/pages/detalhe.md
// Drill-down de Início (Bloom IA) — single-person view com ?person=julio|dani.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/format/dates.dart';
import '../../core/format/money.dart';
import '../../core/rules/personal_summary.dart';
import '../../core/types.dart';
import '../../state/auth_provider.dart';
import '../../state/data_providers.dart';
import '../../theme/bloom_colors.dart';
import '../../theme/bloom_typography.dart';
import '../../widgets/bloom/bloom_card.dart';
import '../../widgets/bloom/bloom_screen.dart';
import '../../widgets/bloom/month_selector.dart';
import '../../widgets/bloom/recent_entry_row.dart';
import '../../widgets/bloom/screen_header.dart';
import '../lancamento/edit_dialog.dart';

class DetalhePage extends ConsumerStatefulWidget {
  final Person? initialPerson;
  const DetalhePage({super.key, this.initialPerson});

  @override
  ConsumerState<DetalhePage> createState() => _DetalhePageState();
}

class _DetalhePageState extends ConsumerState<DetalhePage> {
  late Person _person;

  @override
  void initState() {
    super.initState();
    _person = widget.initialPerson ?? Person.julio;
  }

  @override
  Widget build(BuildContext context) {
    final currentMonth = ref.watch(currentMonthProvider);
    final monthAsync = ref.watch(monthDataProvider(currentMonth));
    final rows = monthAsync.value?.rows ?? const <Entry>[];
    final loading = monthAsync.isLoading && !monthAsync.hasValue;

    final pessoalRows = rows
        .where((r) => r.origem == 'Cartão' && r.rateio == _person.name)
        .toList()
      ..sort((a, b) =>
          parseBrRefDate(b.dataRef).compareTo(parseBrRefDate(a.dataRef)));

    final summary = personalSummaryForPerson(rows, _person);

    Future<void> openEdit(Entry e) async {
      final saved = await showDialog<bool>(
        context: context,
        builder: (_) => EditDialog(
          entry: e,
          rowsForCategoriaSuggestions: rows,
          api: ref.read(apiProvider),
        ),
      );
      if (saved == true) {
        // A linha editada também aparece em Lançamentos e nos agregados.
        ref.invalidate(monthDataProvider);
        ref.invalidate(lastEntriesProvider);
      }
    }

    return BloomScreen(
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ScreenHeader(
              showBack: true,
              kicker: 'Despesas pessoais',
              title: _person.displayName,
              trailing: const MonthSelector(),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: _PersonToggle(
                selected: _person,
                onChanged: (p) => setState(() => _person = p),
              ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: loading
                  ? const BloomCard(
                      padding: EdgeInsets.all(18),
                      child: SizedBox(
                        height: 60,
                        child: Center(
                          child: CircularProgressIndicator(
                              color: BloomColors.violet),
                        ),
                      ),
                    )
                  : Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _Tile(
                                label: 'TOTAL PESSOAL',
                                value: summary.totalPessoal,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _Tile(
                                label: 'CARTÃO PESSOAL',
                                value: summary.cartaoPessoal,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: _Tile(
                                label: 'PARCELADO ATUAL',
                                value: summary.parceladoAtual,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _Tile(
                                label: 'PARCELADO PRÓX',
                                value: summary.parceladoProx,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: Text(
                'Lançamentos pessoais (${pessoalRows.length})',
                style: BloomTypography.display(fontSize: 14),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: BloomCard(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 4),
                child: pessoalRows.isEmpty && !loading
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        child: Center(
                          child: Text(
                            'Sem lançamentos pessoais este mês.',
                            style: BloomTypography.geist(
                              fontSize: 12,
                              color: BloomColors.muted,
                            ),
                          ),
                        ),
                      )
                    : Column(
                        children: [
                          for (var i = 0; i < pessoalRows.length; i++)
                            RecentEntryRow(
                              entry: pessoalRows[i],
                              showDivider: i > 0,
                              hideCategory: true,
                              // Sem row válido (backend antigo) não há o que
                              // editar: o save falharia com invalid_row.
                              onTap: pessoalRows[i].row >= 2
                                  ? () => openEdit(pessoalRows[i])
                                  : null,
                            ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final String label;
  final double value;
  const _Tile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return BloomCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      borderRadius: BorderRadius.circular(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: BloomTypography.kicker(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              'R\$ ${formatMoney(value)}',
              maxLines: 1,
              style: BloomTypography.display(
                fontSize: 18,
                letterSpacing: -0.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PersonToggle extends StatelessWidget {
  final Person selected;
  final ValueChanged<Person> onChanged;

  const _PersonToggle({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < Person.values.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: _ToggleButton(
              person: Person.values[i],
              active: selected == Person.values[i],
              onTap: () => onChanged(Person.values[i]),
            ),
          ),
        ],
      ],
    );
  }
}

class _ToggleButton extends StatelessWidget {
  final Person person;
  final bool active;
  final VoidCallback onTap;

  const _ToggleButton({
    required this.person,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = BloomColors.forPerson(person);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? color : BloomColors.card,
            borderRadius: BorderRadius.circular(14),
            border: active
                ? null
                : Border.all(color: BloomColors.border, width: 1),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.33),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Text(
            person.displayName,
            style: BloomTypography.geist(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: active ? Colors.white : BloomColors.inkSoft,
            ),
          ),
        ),
      ),
    );
  }
}

