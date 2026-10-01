// Spec: docs/specs/pages/categoria.md
// Drill-down de uma linha da tabela do Compart — ?nome=<categoria>.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/format/dates.dart';
import '../../core/format/money.dart';
import '../../core/origem.dart';
import '../../core/rules/categoria_rows.dart';
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

class CategoriaPage extends ConsumerWidget {
  final String categoria;
  const CategoriaPage({super.key, required this.categoria});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentMonth = ref.watch(currentMonthProvider);
    final monthAsync = ref.watch(monthDataProvider(currentMonth));
    final rows = monthAsync.value?.rows ?? const <Entry>[];
    final loading = monthAsync.isLoading && !monthAsync.hasValue;

    int maisRecentePrimeiro(Entry a, Entry b) =>
        parseBrRefDate(b.dataRef).compareTo(parseBrRefDate(a.dataRef));

    final credito =
        categoriaRowsForMonth(rows, categoria, origem: kOrigemCredito)
          ..sort(maisRecentePrimeiro);
    final debito =
        categoriaRowsForMonth(rows, categoria, origem: kOrigemDebito)
          ..sort(maisRecentePrimeiro);

    // Os totais de Crédito continuam sendo os da linha clicada na tabela do
    // Compart (que é só de Crédito); Débito é o grupo que a tabela não mostra.
    final tCredito = categoriaTotais(credito);
    final tDebito = categoriaTotais(debito);
    final totalGeral = tCredito.total + tDebito.total;
    final compartGeral = tCredito.compart + tDebito.compart;

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
              kicker: 'Categoria',
              title: categoria,
              trailing: const MonthSelector(),
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
                                label: 'CRÉDITO',
                                value: tCredito.total,
                                accent: BloomColors.violet,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _Tile(
                                label: 'DÉBITO',
                                value: tDebito.total,
                                accent: BloomColors.sky,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: _Tile(
                                label: 'COMPARTILHADO',
                                value: compartGeral,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _Tile(
                                label: 'TOTAL',
                                value: totalGeral,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 18),
            _Grupo(
              titulo: 'Crédito',
              rows: credito,
              loading: loading,
              vazio: 'Sem lançamentos de crédito nesta categoria.',
              onEdit: openEdit,
            ),
            const SizedBox(height: 18),
            _Grupo(
              titulo: 'Débito',
              rows: debito,
              loading: loading,
              vazio: 'Sem lançamentos de débito nesta categoria.',
              onEdit: openEdit,
            ),
          ],
        ),
      ),
    );
  }
}

class _Grupo extends StatelessWidget {
  final String titulo;
  final List<Entry> rows;
  final bool loading;
  final String vazio;
  final Future<void> Function(Entry) onEdit;

  const _Grupo({
    required this.titulo,
    required this.rows,
    required this.loading,
    required this.vazio,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final total = rows.fold<double>(0, (s, r) => s + r.valor);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(
                  '$titulo (${rows.length})',
                  style: BloomTypography.display(fontSize: 14),
                ),
              ),
              if (rows.isNotEmpty)
                Text(
                  'R\$ ${formatMoney(total)}',
                  style: BloomTypography.mono(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: BloomCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: rows.isEmpty && !loading
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    child: Center(
                      child: Text(
                        vazio,
                        textAlign: TextAlign.center,
                        style: BloomTypography.geist(
                          fontSize: 12,
                          color: BloomColors.muted,
                        ),
                      ),
                    ),
                  )
                : Column(
                    children: [
                      for (var i = 0; i < rows.length; i++)
                        RecentEntryRow(
                          entry: rows[i],
                          showDivider: i > 0,
                          // Todas são da mesma categoria: repeti-la em cada
                          // linha não acrescenta informação.
                          hideCategory: true,
                          onTap: rows[i].row >= 2
                              ? () => onEdit(rows[i])
                              : null,
                        ),
                    ],
                  ),
          ),
        ),
      ],
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
