// Spec: docs/specs/pages/categoria.md
// Drill-down de uma linha da tabela do Compart — ?nome=<categoria>.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/format/dates.dart';
import '../../core/format/money.dart';
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

    final daCategoria = categoriaRowsForMonth(rows, categoria)
      ..sort((a, b) =>
          parseBrRefDate(b.dataRef).compareTo(parseBrRefDate(a.dataRef)));
    final totais = categoriaTotais(daCategoria);

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
                  : Row(
                      children: [
                        Expanded(
                          child: _Tile(
                            label: 'TOTAL',
                            value: totais.total,
                            accent: BloomColors.violet,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _Tile(
                            label: 'COMPARTILHADO',
                            value: totais.compart,
                          ),
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: Text(
                'Lançamentos (${daCategoria.length})',
                style: BloomTypography.display(fontSize: 14),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: BloomCard(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: daCategoria.isEmpty && !loading
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        child: Center(
                          child: Text(
                            'Sem lançamentos nesta categoria.',
                            style: BloomTypography.geist(
                              fontSize: 12,
                              color: BloomColors.muted,
                            ),
                          ),
                        ),
                      )
                    : Column(
                        children: [
                          for (var i = 0; i < daCategoria.length; i++)
                            RecentEntryRow(
                              entry: daCategoria[i],
                              showDivider: i > 0,
                              // Todas são da mesma categoria: repeti-la em cada
                              // linha não acrescenta informação.
                              hideCategory: true,
                              onTap: daCategoria[i].row >= 2
                                  ? () => openEdit(daCategoria[i])
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
