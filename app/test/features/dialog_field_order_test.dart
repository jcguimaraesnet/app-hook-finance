import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hook_finance/api/client.dart';
import 'package:hook_finance/api/config.dart';
import 'package:hook_finance/api/endpoints.dart';
import 'package:hook_finance/core/origem.dart';
import 'package:hook_finance/core/types.dart';
import 'package:hook_finance/features/despesas_fixas/fixed_expense_dialog.dart';
import 'package:hook_finance/features/lancamento/edit_dialog.dart';
import 'package:hook_finance/theme/theme.dart';

ApiEndpoints _api() => ApiEndpoints(ApiClient(const ApiConfig(token: 't')));

Future<void> _pump(WidgetTester tester, Widget dialog) async {
  tester.view.physicalSize = const Size(412, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(theme: buildAppTheme(), home: Scaffold(body: dialog)),
  );
  await tester.pumpAndSettle();
  // Overflow do dropdown "Metade (compartilhado)" é artefato da fonte de teste.
  final err = tester.takeException();
  if (err != null && !err.toString().contains('RenderFlex overflowed')) {
    fail('exceção inesperada: $err');
  }
}

/// Rótulos na ordem vertical em que aparecem.
List<String> _ordem(WidgetTester tester, List<String> rotulos) {
  final comY = <MapEntry<String, double>>[];
  for (final r in rotulos) {
    final f = find.text(r);
    if (f.evaluate().isEmpty) continue;
    comY.add(MapEntry(r, tester.getTopLeft(f.first).dy));
  }
  comY.sort((a, b) => a.value.compareTo(b.value));
  return comY.map((e) => e.key).toList();
}

void main() {
  // A tela de despesas fixas deve ler igual à de lançamento: o campo Origem
  // vem logo depois da data, antes da descrição — não enterrado no meio.
  testWidgets('modal de lançamento: data → Origem → Descrição → Valor',
      (tester) async {
    await _pump(
      tester,
      EditDialog(
        entry: const Entry(
          row: 2,
          data: '06/10/2026',
          dataRef: '18/09/2026 18:17',
          descricao: 'MERCADO',
          valor: 10,
          origem: kOrigemCredito,
          categoria: 'Casa',
          rateio: 'Metade',
          banco: 'Santander',
          parcela: '',
          acerto: '',
        ),
        rowsForCategoriaSuggestions: const [],
        api: _api(),
      ),
    );

    expect(
      _ordem(tester, ['Mês Fatura', 'Origem', 'Descrição', 'Valor (R\$)', 'Categoria', 'Rateio']),
      ['Mês Fatura', 'Origem', 'Descrição', 'Valor (R\$)', 'Categoria', 'Rateio'],
    );
  });

  testWidgets('modal de despesa fixa segue a mesma ordem', (tester) async {
    await _pump(
      tester,
      FixedExpenseDialog(
        entry: const FixedExpense(
          row: 2,
          dia: 6,
          descricao: 'CONDOMINIO',
          valor: 500,
          origem: kOrigemDebito,
          categoria: 'Contas',
          rateio: 'Metade',
          acerto: '',
        ),
        api: _api(),
      ),
    );

    expect(
      _ordem(tester, ['Dia', 'Origem', 'Descrição', 'Valor (R\$)', 'Categoria', 'Rateio']),
      ['Dia', 'Origem', 'Descrição', 'Valor (R\$)', 'Categoria', 'Rateio'],
    );
  });
}
