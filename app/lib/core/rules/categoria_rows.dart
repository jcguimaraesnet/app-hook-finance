// Spec: docs/specs/rules/categoria-rows.md
// Mudanças aqui DEVEM começar pela spec.

import '../origem.dart';
import '../types.dart';

/// Label usada quando a linha não tem categoria. É o que aparece na tabela do
/// Compart e, portanto, o que o drill-down recebe como nome.
const String kCategoriaVazia = '—';

String categoriaLabel(ExpenseRow r) =>
    r.categoria.isEmpty ? kCategoriaVazia : r.categoria;

/// Linhas de Crédito de uma categoria no mês. Mesma regra que o Compart usa
/// para montar cada linha da tabela — é o que faz o detalhamento fechar com o
/// número que foi clicado.
///
/// Genérica em `T` para preservar `Entry` (e o `row` que o editar precisa).
List<T> categoriaRowsForMonth<T extends ExpenseRow>(
  List<T> rows,
  String categoria,
) {
  return rows
      .where((r) => r.origem == kOrigemCredito && categoriaLabel(r) == categoria)
      .toList();
}

/// Os dois números que a linha da tabela mostra: total cheio e a parte que vai
/// para o acerto (metade das linhas `Metade`).
class CategoriaTotais {
  final double total;
  final double compart;

  const CategoriaTotais({required this.total, required this.compart});
}

CategoriaTotais categoriaTotais(List<ExpenseRow> rowsDaCategoria) {
  double total = 0;
  double compart = 0;
  for (final r in rowsDaCategoria) {
    total += r.valor;
    if (r.rateio == 'Metade') compart += r.valor / 2;
  }
  return CategoriaTotais(total: total, compart: compart);
}
