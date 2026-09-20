// Spec: docs/specs/rules/bucket-deltas.md
// Mudanças aqui DEVEM começar pela spec.

import '../origem.dart';
import '../types.dart';
import 'split_for_person.dart';

/// Buckets agregados de uma pessoa para um conjunto de linhas.
class PersonBuckets {
  final double compart;
  final double pessoal;
  final double debito;

  const PersonBuckets({
    required this.compart,
    required this.pessoal,
    required this.debito,
  });

  double get total => compart + pessoal + debito;

  static const zero = PersonBuckets(compart: 0, pessoal: 0, debito: 0);
}

/// Soma `splitForPerson(r, person)` por bucket.
PersonBuckets bucketsForPerson(List<ExpenseRow> rows, Person person) {
  double compart = 0, pessoal = 0, debito = 0;
  for (final r in rows) {
    final v = splitForPerson(r, person);
    if (v == 0) continue;
    if (r.origem == kOrigemCredito) {
      if (r.rateio == 'Metade') {
        compart += v;
      } else {
        pessoal += v;
      }
    } else {
      debito += v;
    }
  }
  return PersonBuckets(compart: compart, pessoal: pessoal, debito: debito);
}

/// Δ% por bucket entre `current` e `previous`. `null` quando previous é 0.
class BucketDeltas {
  final double? compart;
  final double? pessoal;
  final double? debito;

  const BucketDeltas({this.compart, this.pessoal, this.debito});

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
    compart: delta(current.compart, previous.compart),
    pessoal: delta(current.pessoal, previous.pessoal),
    debito: delta(current.debito, previous.debito),
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
