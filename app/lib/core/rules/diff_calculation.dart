// Spec: docs/specs/rules/diff-calculation.md
// Mudanças aqui DEVEM começar pela spec.

import '../types.dart';
import 'acerto_total.dart';

/// Quanto a pessoa pagou a mais (ou a menos) que a outra em **Débito (outros)**
/// no mês — a linha do card de Acerto com origem Débito, rateio da pessoa e
/// categoria diferente de `Pessoal`.
///
/// Desde 2026-10-01 é exatamente a diferença entre as duas linhas `Débito
/// (outros)` que a tela mostra, uma de cada pessoa. Antes somava **todo** o
/// Débito que tocava cada um: as linhas da categoria `Pessoal` (Dízimo,
/// Previdência) entravam na conta, embora não sejam despesa da casa que um
/// pagou pelo outro, e o número do pill não aparecia em lugar nenhum da tabela.
///
/// Linhas `Compartilhado` não entram: já são metade de cada um e se cancelariam.
double diffCalculation(List<ExpenseRow> rows, Person person) {
  double outros(Person p) =>
      acertoDebitoRows(rows, p).outros.fold<double>(0, (s, r) => s + r.valor);

  return outros(person) - outros(person.other);
}
