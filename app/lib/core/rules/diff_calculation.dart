// Spec: docs/specs/rules/diff-calculation.md
// Mudanças aqui DEVEM começar pela spec.

import '../types.dart';
import 'acerto_total.dart';

/// Quanto a pessoa pagou a mais (ou a menos) que a outra em débito da casa no
/// mês: origem Débito, rateio da pessoa, categoria diferente de `Pessoal`.
///
/// Até 2026-10-01 somava **todo** o débito que tocava cada um, e as linhas da
/// categoria `Pessoal` (Dízimo, Previdência) entravam na conta embora não sejam
/// despesa da casa que um pagou pelo outro. O usuário pediu que saíssem.
///
/// ⚠️ De 2026-10-01 a 2026-10-02 esta era exatamente a diferença entre as duas
/// linhas `Débito (outros)` da tela. Essa linha sumiu quando a tabela foi
/// simetrizada, então **o número não corresponde mais a nenhuma linha visível**
/// — é menor que a diferença entre os dois `Débito (pessoal)` exibidos. A regra
/// ficou como estava de propósito: mudá-la junto com um ajuste de layout
/// alteraria dinheiro sem ninguém ter pedido.
///
/// Linhas `Compartilhado` não entram: já são metade de cada um e se cancelariam.
double diffCalculation(List<ExpenseRow> rows, Person person) {
  double daCasa(Person p) =>
      debitoParaDiferenca(rows, p).fold<double>(0, (s, r) => s + r.valor);

  return daCasa(person) - daCasa(person.other);
}
