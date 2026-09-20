// Spec: docs/specs/pages/contas.md
// Drill-down da coluna Contas do Comparativo (Início) — ?person=julio|dani.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/format/dates.dart';
import '../../core/format/money.dart';
import '../../core/rules/contas_rows.dart';
import '../../core/rules/split_for_person.dart';
import '../../core/types.dart';
import '../../state/auth_provider.dart';
import '../../state/data_providers.dart';
import '../../theme/bloom_colors.dart';
import '../../theme/bloom_typography.dart';
import '../../widgets/bloom/bloom_card.dart';
import '../../widgets/bloom/bloom_screen.dart';
import '../../widgets/bloom/month_selector.dart';
import '../../widgets/bloom/person_toggle.dart';
import '../../widgets/bloom/recent_entry_row.dart';
import '../../widgets/bloom/screen_header.dart';
import '../lancamento/edit_dialog.dart';

class ContasPage extends ConsumerStatefulWidget {
  final Person? initialPerson;
  const ContasPage({super.key, this.initialPerson});

  @override
  ConsumerState<ContasPage> createState() => _ContasPageState();
}

class _ContasPageState extends ConsumerState<ContasPage> {
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

    final contasRows = contasRowsForPerson(rows, _person)
      ..sort((a, b) =>
          parseBrRefDate(b.dataRef).compareTo(parseBrRefDate(a.dataRef)));

    // "Sua parte" tem que bater com a coluna Contas do Comparativo, que é de
    // onde se chega aqui — mesma regra, ver docs/specs/rules/contas-rows.md.
    double suaParte = 0;
    double totalCheio = 0;
    for (final r in contasRows) {
      suaParte += splitForPerson(r, _person);
      totalCheio += r.valor;
    }
    final mostrarCheio = (totalCheio - suaParte).abs() >= 0.005;

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
              kicker: 'Contas',
              title: _person.displayName,
              trailing: const MonthSelector(),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: PersonToggle(
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
                  : Row(
                      children: [
                        Expanded(
                          child: _Tile(
                            label: mostrarCheio ? 'SUA PARTE' : 'TOTAL',
                            value: suaParte,
                            accent: BloomColors.sky,
                          ),
                        ),
                        // Sem linha "Metade" nas contas do mês os dois tiles
                        // mostrariam o mesmo número — parece bug, então some.
                        if (mostrarCheio) ...[
                          const SizedBox(width: 10),
                          Expanded(
                            child: _Tile(
                              label: 'TOTAL CHEIO',
                              value: totalCheio,
                            ),
                          ),
                        ],
                      ],
                    ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: Text(
                'Lançamentos de contas (${contasRows.length})',
                style: BloomTypography.display(fontSize: 14),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: BloomCard(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: contasRows.isEmpty && !loading
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        child: Center(
                          child: Text(
                            'Sem contas neste mês.',
                            style: BloomTypography.geist(
                              fontSize: 12,
                              color: BloomColors.muted,
                            ),
                          ),
                        ),
                      )
                    : Column(
                        children: [
                          for (var i = 0; i < contasRows.length; i++)
                            RecentEntryRow(
                              entry: contasRows[i],
                              showDivider: i > 0,
                              onTap: contasRows[i].row >= 2
                                  ? () => openEdit(contasRows[i])
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
  final Color? accent;

  const _Tile({required this.label, required this.value, this.accent});

  @override
  Widget build(BuildContext context) {
    return BloomCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      borderRadius: BorderRadius.circular(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (accent != null) ...[
                Container(
                  width: 6,
                  height: 6,
                  decoration:
                      BoxDecoration(color: accent, shape: BoxShape.circle),
                ),
                const SizedBox(width: 5),
              ],
              Expanded(
                child: Text(
                  label,
                  style: BloomTypography.kicker(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
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
