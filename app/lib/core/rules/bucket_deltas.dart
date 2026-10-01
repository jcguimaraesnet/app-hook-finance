// Spec: docs/specs/rules/bucket-deltas.md
// Mudanças aqui DEVEM começar pela spec.

import '../rateio.dart';
import '../origem.dart';
import '../types.dart';
import 'split_for_person.dart';

/// Buckets agregados de uma pessoa para um conjunto de linhas.
///
/// São os **quatro quadrantes** `(Crédito | Débito) × (compartilhado | pessoal)`
/// que o card de totais da Início mostra em 2×2. Eles particionam o total: toda
/// linha com `splitForPerson != 0` cai em exatamente um.
class PersonBuckets {
  /// Dividido no cartão: origem Crédito com rateio `Compartilhado`.
  final double credito;

  /// Dividido fora do cartão: origem Débito com rateio `Compartilhado`.
  final double debito;

  /// Rateio da pessoa na origem Crédito.
  final double pessoalCredito;

  /// Rateio da pessoa na origem Débito.
  final double pessoalDebito;

  const PersonBuckets({
    required this.credito,
    required this.debito,
    required this.pessoalCredito,
    required this.pessoalDebito,
  });

  /// Tudo que é da pessoa: rateio dela, em **qualquer** origem.
  double get pessoal => pessoalCredito + pessoalDebito;

  /// Tudo que é dividido, nas duas origens. É uma das duas fatias do donut da
  /// Início desde 2026-10-01 (a outra é `pessoal`); antes eram três, com
  /// Crédito e Débito separados no gráfico. Os quatro quadrantes continuam
  /// separados aqui porque o card de totais os mostra um a um.
  double get compartilhado => credito + debito;

  double get total => compartilhado + pessoal;

  static const zero = PersonBuckets(
    credito: 0,
    debito: 0,
    pessoalCredito: 0,
    pessoalDebito: 0,
  );
}

/// Soma `splitForPerson(r, person)` por quadrante.
PersonBuckets bucketsForPerson(List<ExpenseRow> rows, Person person) {
  double credito = 0, debito = 0, pessoalCredito = 0, pessoalDebito = 0;
  for (final r in rows) {
    final v = splitForPerson(r, person);
    if (v == 0) continue;
    // Pós-2026-10-01 o corte é por rateio primeiro, origem depois: o que é da
    // pessoa é "pessoal" venha de Crédito ou Débito. Antes, Débito caía inteiro
    // na fatia de débito mesmo sendo rateio individual.
    final isCredito = r.origem == kOrigemCredito;
    if (r.rateio == person.name) {
      if (isCredito) {
        pessoalCredito += v;
      } else {
        pessoalDebito += v;
      }
    } else if (r.rateio == kRateioCompartilhado) {
      if (isCredito) {
        credito += v;
      } else {
        debito += v;
      }
    }
  }
  return PersonBuckets(
    credito: credito,
    debito: debito,
    pessoalCredito: pessoalCredito,
    pessoalDebito: pessoalDebito,
  );
}

/// Calcula o mês anterior preservando o formato de entrada.
/// Aceita `MM/YYYY` ou `DD/MM/YYYY`. Retorna `null` se o formato for outro.
String? previousMonthOf(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  final parts = raw.split('/');
  int? m;
  int? y;
  String? day;
  if (parts.length == 2) {
    m = int.tryParse(parts[0]);
    y = int.tryParse(parts[1]);
  } else if (parts.length == 3) {
    day = parts[0];
    m = int.tryParse(parts[1]);
    y = int.tryParse(parts[2]);
  } else {
    return null;
  }
  if (m == null || y == null) return null;
  final prevMonth = m == 1 ? 12 : m - 1;
  final prevYear = m == 1 ? y - 1 : y;
  final mm = prevMonth.toString().padLeft(2, '0');
  if (day != null) return '$day/$mm/$prevYear';
  return '$mm/$prevYear';
}
