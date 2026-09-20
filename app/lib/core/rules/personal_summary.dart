// Spec: docs/specs/rules/personal-summary.md
// Mudanças aqui DEVEM começar pela spec.

import '../origem.dart';
import '../types.dart';

class PersonalSummary {
  final double totalPessoal;
  final double cartaoPessoal;
  final double parceladoAtual;
  final double parceladoProx;

  const PersonalSummary({
    required this.totalPessoal,
    required this.cartaoPessoal,
    required this.parceladoAtual,
    required this.parceladoProx,
  });

  static const zero = PersonalSummary(
    totalPessoal: 0,
    cartaoPessoal: 0,
    parceladoAtual: 0,
    parceladoProx: 0,
  );
}

PersonalSummary personalSummaryForPerson(
  List<ExpenseRow> rows,
  Person person,
) {
  double totalPessoal = 0;
  double cartaoPessoal = 0;
  double parceladoAtual = 0;
  double parceladoProx = 0;

  for (final r in rows) {
    if (r.rateio != person.name) continue;
    totalPessoal += r.valor;
    if (r.origem != kOrigemCredito) continue;
    cartaoPessoal += r.valor;
    final (x, y) = _parseParcela(r.parcela);
    if (y <= 1) continue;
    parceladoAtual += r.valor;
    if (x < y) parceladoProx += r.valor;
  }

  return PersonalSummary(
    totalPessoal: totalPessoal,
    cartaoPessoal: cartaoPessoal,
    parceladoAtual: parceladoAtual,
    parceladoProx: parceladoProx,
  );
}

// Parse "X/Y" → (X, Y). Vazio, legado ("3") ou inválido → (1, 1) (à vista).
(int, int) _parseParcela(String raw) {
  final s = raw.trim();
  if (s.isEmpty) return (1, 1);
  if (!s.contains('/')) return (1, 1);
  final parts = s.split('/');
  if (parts.length != 2) return (1, 1);
  final x = int.tryParse(parts[0]) ?? 0;
  final y = int.tryParse(parts[1]) ?? 0;
  if (x <= 0 || y <= 0) return (1, 1);
  return (x, y);
}
