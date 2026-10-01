// Spec: docs/specs/rules/bucket-key.md
// Mudanças aqui DEVEM começar pela spec.

import '../rateio.dart';
import '../origem.dart';
import '../types.dart';

String bucketKey(ExpenseRow row) {
  if (row.origem == kOrigemCredito) {
    return row.rateio == kRateioCompartilhado
        ? 'Crédito (compartilhado)'
        : 'Crédito (pessoal)';
  }
  return row.origem;
}
