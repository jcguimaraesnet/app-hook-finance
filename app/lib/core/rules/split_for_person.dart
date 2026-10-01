// Spec: docs/specs/rules/split-for-person.md
// Mudanças aqui DEVEM começar pela spec.

import '../rateio.dart';
import '../types.dart';

double splitForPerson(ExpenseRow row, Person person) {
  if (row.rateio == person.name) return row.valor;
  if (row.rateio == kRateioCompartilhado &&
      (person == Person.julio || person == Person.dani)) {
    return row.valor / 2;
  }
  return 0;
}
