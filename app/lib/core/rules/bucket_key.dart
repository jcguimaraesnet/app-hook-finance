// Spec: docs/specs/rules/bucket-key.md
// Mudanças aqui DEVEM começar pela spec.

import '../origem.dart';
import '../types.dart';

String bucketKey(ExpenseRow row) {
  if (row.origem == kOrigemCredito) {
    return row.rateio == 'Metade'
        ? 'Crédito (compartilhado)'
        : 'Crédito (pessoal)';
  }
  return row.origem;
}
