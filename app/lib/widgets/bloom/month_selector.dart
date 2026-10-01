// Pílula "MM/YYYY ▾" — abre um menu com a lista de meses disponíveis.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/format/dates.dart';
import '../../state/data_providers.dart';
import '../../theme/bloom_colors.dart';
import '../../theme/bloom_typography.dart';

class MonthSelector extends ConsumerWidget {
  /// Rótulo abreviado ("Nov 2026"). A Início usa a pílula na barra de topo,
  /// ao lado do título e do menu, onde "Novembro, 2026" não cabe.
  final bool abbrev;

  const MonthSelector({super.key, this.abbrev = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final months = ref.watch(allMonthsProvider);
    final current = ref.watch(currentMonthProvider);
    final monthAsync = ref.watch(monthDataProvider(current));
    final raw = current ?? monthAsync.value?.month;
    final display = abbrev ? monthYearAbbrev(raw) : monthYearLong(raw);

    final disabled = months.isEmpty;

    return _PillButton(
      label: display == '—' ? '— ▾' : '$display ▾',
      onTap: disabled
          ? null
          : () async {
              final picked = await _pickMonth(context, months, current);
              if (picked != null) {
                ref.read(currentMonthProvider.notifier).state = picked;
              }
            },
    );
  }

  Future<String?> _pickMonth(
    BuildContext context,
    List<String> months,
    String? current,
  ) async {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: BloomColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: Text(
                    'Selecione o mês',
                    style: BloomTypography.geist(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: months.length,
                    itemBuilder: (_, i) {
                      final m = months[i];
                      final isActive = m == current;
                      return InkWell(
                        onTap: () => Navigator.of(ctx).pop(m),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  monthYearLong(m),
                                  style: BloomTypography.geist(
                                    fontSize: 14,
                                    fontWeight: isActive
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: isActive
                                        ? BloomColors.violet
                                        : BloomColors.ink,
                                  ),
                                ),
                              ),
                              if (isActive)
                                const Icon(Icons.check,
                                    size: 18, color: BloomColors.violet),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PillButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const _PillButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: BloomColors.card,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: BloomColors.border, width: 1),
          ),
          child: Text(
            label,
            style: BloomTypography.mono(
              fontSize: 11,
              color: BloomColors.inkSoft,
            ),
          ),
        ),
      ),
    );
  }
}
