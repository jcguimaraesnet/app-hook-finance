// Spec: docs/specs/rules/debito-rows.md
// Mudanças aqui DEVEM começar pela spec.

import '../origem.dart';
import '../types.dart';
import 'split_for_person.dart';

/// Linhas do bucket "Débito" de uma pessoa: origem Débito e rateio que toca a
/// pessoa. Mesma dupla de filtros que `bucketsForPerson` usa para somar a coluna
/// Débito do Comparativo — é o que faz a lista fechar com o total.
///
/// Genérica em `T` para preservar `Entry` (e o `row` que o editar precisa).
List<T> debitoRowsForPerson<T extends ExpenseRow>(
  List<T> rows,
  Person person,
) {
  return rows
      .where((r) => r.origem == kOrigemDebito && splitForPerson(r, person) != 0)
      .toList();
}

/// Σ da parte da pessoa nas linhas de Débito. Igual a
/// `bucketsForPerson(rows, person).debito` — ver a invariante na spec.
double debitoShareForPerson(List<ExpenseRow> rows, Person person) {
  double total = 0;
  for (final r in debitoRowsForPerson(rows, person)) {
    total += splitForPerson(r, person);
  }
  return total;
}
