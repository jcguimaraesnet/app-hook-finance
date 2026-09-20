// Spec: docs/specs/pages/despesas-fixas.md
// Edita a aba de configuração que a Nova fatura usa como template.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/format/money.dart';
import '../../core/origem.dart';
import '../../core/types.dart';
import '../../state/auth_provider.dart';
import '../../state/data_providers.dart';
import '../../theme/bloom_colors.dart';
import '../../theme/bloom_typography.dart';
import '../../widgets/bloom/bloom_card.dart';
import '../../widgets/bloom/bloom_screen.dart';
import '../../widgets/bloom/screen_header.dart';
import 'fixed_expense_dialog.dart';

class DespesasFixasPage extends ConsumerWidget {
  const DespesasFixasPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(fixedExpensesProvider);
    final rows = async.value?.rows ?? const <FixedExpense>[];
    final loading = async.isLoading && !async.hasValue;

    final total = rows.fold<double>(0, (s, r) => s + r.valor);
    final invalidas = rows.where((r) => !r.isValid).length;

    Future<void> abrir(FixedExpense? atual) async {
      final salvou = await showDialog<bool>(
        context: context,
        builder: (_) => FixedExpenseDialog(
          entry: atual,
          api: ref.read(apiProvider),
        ),
      );
      if (salvou == true) ref.invalidate(fixedExpensesProvider);
    }

    return BloomScreen(
      child: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(fixedExpensesProvider);
          await ref.read(fixedExpensesProvider.future);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const ScreenHeader(
                showBack: true,
                kicker: 'Configuração',
                title: 'Despesas fixas',
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: Text(
                  'Template que a Nova fatura insere no topo da planilha. A ordem '
                  'das linhas aqui é a ordem em que elas entram na fatura.',
                  style: BloomTypography.geist(
                    fontSize: 12,
                    color: BloomColors.muted,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              if (async.hasError)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  child: _Aviso(
                    cor: BloomColors.bad,
                    texto: 'Falha ao carregar: ${async.error}',
                  ),
                )
              else ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  child: Row(
                    children: [
                      Expanded(
                        child: _Tile(
                          label: 'TOTAL MENSAL',
                          value: 'R\$ ${formatMoney(total)}',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _Tile(
                          label: 'LINHAS',
                          value: '${rows.length}',
                        ),
                      ),
                    ],
                  ),
                ),
                if (invalidas > 0) ...[
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    child: _Aviso(
                      cor: BloomColors.bad,
                      texto: invalidas == 1
                          ? '1 linha inválida trava a criação da próxima fatura. Toque para corrigir.'
                          : '$invalidas linhas inválidas travam a criação da próxima fatura. Toque para corrigir.',
                    ),
                  ),
                ],
              ],
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: BloomCard(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: loading
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child: CircularProgressIndicator(
                                color: BloomColors.violet),
                          ),
                        )
                      : rows.isEmpty
                          ? Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 18),
                              child: Center(
                                child: Text(
                                  'Nenhuma despesa fixa cadastrada.',
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
                                  _LinhaFixa(
                                    entry: rows[i],
                                    showDivider: i > 0,
                                    onTap: () => abrir(rows[i]),
                                  ),
                              ],
                            ),
                ),
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: FilledButton.icon(
                  onPressed: () => abrir(null),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Nova despesa fixa'),
                  style: FilledButton.styleFrom(
                    backgroundColor: BloomColors.violet,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
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

class _LinhaFixa extends StatelessWidget {
  final FixedExpense entry;
  final bool showDivider;
  final VoidCallback onTap;

  const _LinhaFixa({
    required this.entry,
    required this.showDivider,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tone = entry.isValid ? BloomColors.ink : BloomColors.bad;
    return Column(
      children: [
        if (showDivider)
          const Divider(height: 1, color: BloomColors.divider),
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 11),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: tone.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    entry.dia > 0 ? '${entry.dia}' : '—',
                    style: BloomTypography.display(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: tone,
                      height: 1,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.descricao.isEmpty ? '(sem descrição)' : entry.descricao,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: BloomTypography.geist(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: tone,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        entry.isValid
                            ? [
                                entry.rateio,
                                entry.origem,
                                if (entry.acerto == 'Sim') 'acerto',
                                if (entry.isParcelada)
                                  'faltam ${entry.parcelasRestantes}',
                              ].join(' · ')
                            : entry.invalid,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: BloomTypography.geist(
                          fontSize: 11,
                          color: entry.isValid
                              ? BloomColors.muted
                              : BloomColors.bad,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'R\$ ${formatMoney(entry.valor)}',
                  style: BloomTypography.mono(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Icon(Icons.chevron_right,
                    size: 16, color: BloomColors.muted),
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
  final String value;
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
          Text(label, style: BloomTypography.kicker(), maxLines: 1),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
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

class _Aviso extends StatelessWidget {
  final Color cor;
  final String texto;
  const _Aviso({required this.cor, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cor.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, size: 16, color: cor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              texto,
              style: BloomTypography.geist(
                  fontSize: 11.5, color: cor, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

/// Exposto para o dialog reusar a mesma lista de origens da col D.
const List<String> kFixedOrigens = kOrigens;
