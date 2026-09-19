// Spec: docs/specs/rules/contas-rows.md
// Mudanças aqui DEVEM começar pela spec.

import '../types.dart';
import 'split_for_person.dart';

/// Linhas do bucket "Contas" de uma pessoa: tudo que não é Cartão e cujo rateio
/// toca a pessoa. Mesma dupla de filtros que `bucketsForPerson` usa para somar a
/// coluna Contas do Comparativo — é o que faz a lista fechar com o total.
///
/// Genérica em `T` para preservar `Entry` (e o `row` que o editar precisa).
List<T> contasRowsForPerson<T extends ExpenseRow>(
  List<T> rows,
  Person person,
) {
  return rows
      .where((r) => r.origem != 'Cartão' && splitForPerson(r, person) != 0)
      .toList();
}

/// Σ da parte da pessoa nas linhas de Contas. Igual a
/// `bucketsForPerson(rows, person).contas` — ver a invariante na spec.
double contasShareForPerson(List<ExpenseRow> rows, Person person) {
  double total = 0;
  for (final r in contasRowsForPerson(rows, person)) {
    total += splitForPerson(r, person);
  }
  return total;
}
