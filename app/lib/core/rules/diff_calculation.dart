// Spec: docs/specs/rules/diff-calculation.md
// Mudanças aqui DEVEM começar pela spec.

import '../origem.dart';
import '../types.dart';
import 'split_for_person.dart';

/// Quanto a pessoa pagou a mais (ou a menos) que a outra em Débito no mês.
///
/// Até a migração de Origem (2026-09-20) havia dois ramos: se o mês tivesse
/// "Pix (contas)" somava só Pix, senão somava "Contas" + "Empregados". Os três
/// viraram Débito. O número não mudou em nenhum dos 12 meses da planilha, e não
/// por acaso: os dois conjuntos nunca coexistiram num mesmo mês — o ramo era, na
/// prática, um seletor de era.
double diffCalculation(List<ExpenseRow> rows, Person person) {
  final other = person.other;
  double meu = 0;
  double outro = 0;
  for (final r in rows) {
    if (r.origem != kOrigemDebito) continue;
    meu += splitForPerson(r, person);
    outro += splitForPerson(r, other);
  }
  return meu - outro;
}
