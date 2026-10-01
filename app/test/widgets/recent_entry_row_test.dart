import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hook_finance/core/origem.dart';
import 'package:hook_finance/core/types.dart';
import 'package:hook_finance/theme/theme.dart';
import 'package:hook_finance/widgets/bloom/recent_entry_row.dart';

Entry _e({
  String descricao = 'SHOPPING ESTACAO',
  String dataRef = '30/09/2026 22:16',
  String data = '06/11/2026',
  String categoria = 'Pessoal',
  String parcela = '',
  String rateio = 'Dani',
}) =>
    Entry(
      row: 2,
      data: data,
      dataRef: dataRef,
      descricao: descricao,
      valor: 22.5,
      origem: kOrigemCredito,
      categoria: categoria,
      rateio: rateio,
      banco: '',
      parcela: parcela,
      acerto: '',
    );

Future<void> _pump(WidgetTester tester, Entry e,
    {bool hideCategory = false}) async {
  tester.view.physicalSize = const Size(412, 400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(),
      home: Scaffold(
        body: RecentEntryRow(entry: e, hideCategory: hideCategory),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  // Pós-2026-10-01 a data sai da meta-linha e vai para a direita da descrição,
  // em DD/MM: a meta tinha data, categoria e parcela disputando 10px.
  testWidgets('data vai para a linha da descrição, em DD/MM', (tester) async {
    await _pump(tester, _e(dataRef: '30/09/2026 22:16'));

    expect(find.text('30/09'), findsOneWidget);
    expect(find.text('30/09/2026'), findsNothing);
    final desc = tester.getRect(find.text('SHOPPING ESTACAO'));
    final data = tester.getRect(find.text('30/09'));
    // Mesma linha: as faixas verticais se sobrepõem (alinhados pela baseline,
    // com tamanhos de fonte diferentes, os tops não coincidem).
    expect(data.top, lessThan(desc.bottom));
    expect(desc.top, lessThan(data.bottom));
    // E à direita do texto da descrição, não em cima dele.
    expect(data.left, greaterThanOrEqualTo(desc.right));
    expect(find.text('Pessoal'), findsOneWidget);
  });

  testWidgets('meta mantém categoria e parcela, sem a data', (tester) async {
    await _pump(tester, _e(categoria: 'Casa', parcela: '2/12'));
    expect(find.text('Casa · (2 / 12)'), findsOneWidget);
  });

  testWidgets('hideCategory sem parcela não deixa separador solto',
      (tester) async {
    await _pump(tester, _e(categoria: 'Casa'), hideCategory: true);
    expect(find.textContaining('·'), findsNothing);
  });

  testWidgets('hideCategory com parcela mostra só a parcela', (tester) async {
    await _pump(tester, _e(parcela: '1/3'), hideCategory: true);
    expect(find.text('(1 / 3)'), findsOneWidget);
  });

  testWidgets('sem dataRef cai para a col A (data da fatura)', (tester) async {
    await _pump(tester, _e(dataRef: '', data: '06/11/2026'));
    expect(find.text('06/11'), findsOneWidget);
  });
}
