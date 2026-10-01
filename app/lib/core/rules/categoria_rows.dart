// Spec: docs/specs/rules/categoria-rows.md
// Mudanças aqui DEVEM começar pela spec.

import '../rateio.dart';
import '../types.dart';

/// Label usada quando a linha não tem categoria. É o que aparece na tabela do
/// Compart e, portanto, o que o drill-down recebe como nome.
const String kCategoriaVazia = '—';

String categoriaLabel(ExpenseRow r) =>
    r.categoria.isEmpty ? kCategoriaVazia : r.categoria;

/// Linhas de uma categoria no mês, por origem. `origem` é obrigatório de
/// propósito: com Crédito reproduz exatamente a linha da tabela do Compart (é o
/// que faz o detalhamento fechar com o número clicado), e com Débito dá o grupo
/// que a tabela não mostra. Um default escondido aqui seria a forma mais fácil
/// de somar coisa errada.
///
/// Genérica em `T` para preservar `Entry` (e o `row` que o editar precisa).
List<T> categoriaRowsForMonth<T extends ExpenseRow>(
  List<T> rows,
  String categoria, {
  required String origem,
}) {
  return rows
      .where((r) => r.origem == origem && categoriaLabel(r) == categoria)
      .toList();
}

/// Os dois números que a linha da tabela mostra: total cheio e a parte que vai
/// para o acerto (metade das linhas `Metade`).
class CategoriaTotais {
  final double total;
  final double compart;

  const CategoriaTotais({required this.total, required this.compart});
}

/// Total cheio e parte compartilhada de um conjunto já filtrado. Vale para
/// qualquer origem — quem filtra decide o recorte.
CategoriaTotais categoriaTotais(List<ExpenseRow> rowsDaCategoria) {
  double total = 0;
  double compart = 0;
  for (final r in rowsDaCategoria) {
    total += r.valor;
    if (r.rateio == kRateioCompartilhado) compart += r.valor / 2;
  }
  return CategoriaTotais(total: total, compart: compart);
}
