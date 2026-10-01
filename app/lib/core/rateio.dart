// Spec: docs/specs/data/despesas-sheet.md (col G)
// Mudanças aqui DEVEM começar pela spec.

/// Rateio compartilhado. Chamava-se `Metade` até 2026-10-01; a planilha inteira
/// (3.384 linhas) foi migrada por `migrateRateio`.
const String kRateioCompartilhado = 'Compartilhado';

const List<String> kRateios = [
  '',
  'Julio',
  'Dani',
  kRateioCompartilhado,
  'Alzira',
];

/// Converte o termo antigo na leitura. Ponte temporária, como a de origem:
/// protege contra linha que escape da migração ou seja digitada à mão.
String normalizeRateio(String raw) {
  final v = raw.trim();
  return v == 'Metade' ? kRateioCompartilhado : v;
}
