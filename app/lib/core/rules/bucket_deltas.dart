// Spec: docs/specs/rules/bucket-deltas.md
// Mudanças aqui DEVEM começar pela spec.

import '../rateio.dart';
import '../origem.dart';
import '../types.dart';
import 'split_for_person.dart';

/// Buckets agregados de uma pessoa para um conjunto de linhas.
class PersonBuckets {
  /// Dividido no cartão: origem Crédito com rateio `Metade`.
  final double credito;

  /// Tudo que é da pessoa: rateio dela, em **qualquer** origem.
  final double pessoal;

  /// Dividido fora do cartão: origem Débito com rateio `Metade`.
  final double debito;

  const PersonBuckets({
    required this.credito,
    required this.pessoal,
    required this.debito,
  });

  /// Tudo que é dividido, nas duas origens. É o agrupamento que a Início mostra
  /// desde 2026-10-01: donut e Comparação passaram de três fatias
  /// (Crédito · Débito · Pessoal) para duas (Compartilhado · Pessoal). Crédito e
  /// Débito continuam separados aqui porque os tiles abaixo do Comparação ainda
  /// mostram os dois, e porque a conta de cada um é a que a aba Categoria usa.
  double get compartilhado => credito + debito;

  double get total => credito + pessoal + debito;

  static const zero = PersonBuckets(credito: 0, pessoal: 0, debito: 0);
}

/// Soma `splitForPerson(r, person)` por bucket.
PersonBuckets bucketsForPerson(List<ExpenseRow> rows, Person person) {
  double credito = 0, pessoal = 0, debito = 0;
  for (final r in rows) {
    final v = splitForPerson(r, person);
    if (v == 0) continue;
    // Pós-2026-10-01 o corte é por rateio primeiro, origem depois: o que é da
    // pessoa é "pessoal" venha de Crédito ou Débito, e as duas outras fatias
    // são só o que está dividido (`Metade`). Antes, Débito caía inteiro na
    // fatia de débito mesmo sendo rateio individual.
    if (r.rateio == person.name) {
      pessoal += v;
    } else if (r.rateio == kRateioCompartilhado) {
      if (r.origem == kOrigemCredito) {
        credito += v;
      } else {
        debito += v;
      }
    }
  }
  return PersonBuckets(credito: credito, pessoal: pessoal, debito: debito);
}

/// Δ% por bucket entre `current` e `previous`. `null` quando previous é 0.
class BucketDeltas {
  final double? credito;
  final double? pessoal;
  final double? debito;

  /// Δ do agrupamento `compartilhado`. Calculado sobre a soma, não a partir dos
  /// Δ de crédito e débito: a média de dois percentuais não é o percentual da
  /// soma, e um dos dois pode ser `null`.
  final double? compartilhado;

  const BucketDeltas({
    this.credito,
    this.pessoal,
    this.debito,
    this.compartilhado,
  });

  static const empty = BucketDeltas();
}

BucketDeltas bucketDeltas({
  required PersonBuckets current,
  required PersonBuckets previous,
}) {
  double? delta(double cur, double prev) {
    if (prev == 0) return null;
    return (cur - prev) / prev * 100;
  }

  return BucketDeltas(
    credito: delta(current.credito, previous.credito),
    pessoal: delta(current.pessoal, previous.pessoal),
    debito: delta(current.debito, previous.debito),
    compartilhado: delta(current.compartilhado, previous.compartilhado),
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
