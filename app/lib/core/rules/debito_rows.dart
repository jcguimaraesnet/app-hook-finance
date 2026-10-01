// Spec: docs/specs/rules/debito-rows.md
// Mudanças aqui DEVEM começar pela spec.

import '../origem.dart';
import '../types.dart';
import 'split_for_person.dart';

/// Linhas da fatia "Débito": origem Débito com rateio `Metade`.
///
/// Desde 2026-10-01 a fatia conta só o que está dividido — o débito de rateio
/// individual passou a somar em "Pessoal" e aparece na tela de Despesas
/// pessoais. Esta lista acompanha a fatia, senão a tela mostraria um total
/// diferente do número que foi clicado.
///
/// Genérica em `T` para preservar `Entry` (e o `row` que o editar precisa).
List<T> debitoRowsForPerson<T extends ExpenseRow>(
  List<T> rows,
  Person person,
) {
  return rows
      .where((r) =>
          r.origem == kOrigemDebito &&
          r.rateio == 'Metade' &&
          splitForPerson(r, person) != 0)
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
