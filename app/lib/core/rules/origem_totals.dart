// Spec: docs/specs/pages/inicio.md
// Mudanças aqui DEVEM começar pela spec.

import '../origem.dart';
import '../types.dart';
import 'split_for_person.dart';

/// Crédito e Débito do mês somando as **duas** pessoas.
///
/// Cada linha entra pelo que cabe a cada um (`splitForPerson` dos dois), não
/// pelo valor cheio: uma linha `Compartilhado` volta inteira (metade + metade),
/// uma linha individual entra inteira para o dono, e uma linha de terceiro
/// (rateio `Alzira` ou vazio) fica de fora — como já fica no resto da Início.
///
/// Com isso `credito + debito` é exatamente o total do Júlio mais o da Dani,
/// que são os dois tiles logo acima na tela. Conferido em 06/11/2026:
/// 4.194,86 + 12.027,25 = 16.222,11 = 7.339,05 + 8.883,06.
class OrigemTotals {
  final double credito;
  final double debito;

  const OrigemTotals({required this.credito, required this.debito});

  double get total => credito + debito;

  static const zero = OrigemTotals(credito: 0, debito: 0);
}

OrigemTotals origemTotals(List<ExpenseRow> rows) {
  double credito = 0, debito = 0;
  for (final r in rows) {
    final v = splitForPerson(r, Person.julio) + splitForPerson(r, Person.dani);
    if (v == 0) continue;
    if (r.origem == kOrigemCredito) {
      credito += v;
    } else if (r.origem == kOrigemDebito) {
      debito += v;
    }
  }
  return OrigemTotals(credito: credito, debito: debito);
}
