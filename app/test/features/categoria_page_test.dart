import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hook_finance/core/origem.dart';
import 'package:hook_finance/core/rules/categoria_rows.dart';
import 'package:hook_finance/core/types.dart';
import 'package:hook_finance/features/categoria/categoria_page.dart';
import 'package:hook_finance/state/data_providers.dart';
import 'package:hook_finance/theme/theme.dart';

Entry _e({
  required int row,
  String categoria = 'Casa',
  String rateio = 'Metade',
  double valor = 100,
  String descricao = 'MERCADO',
  String origem = kOrigemCredito,
  String dataRef = '18/09/2026 10:00',
}) =>
    Entry(
      row: row,
      data: '06/10/2026',
      dataRef: dataRef,
      descricao: descricao,
      valor: valor,
      origem: origem,
      categoria: categoria,
      rateio: rateio,
      banco: '',
      parcela: '',
      acerto: '',
    );

Future<void> _pump(WidgetTester tester, List<Entry> rows, String categoria) async {
  tester.view.physicalSize = const Size(412, 915);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        monthDataProvider.overrideWith(
          (ref, month) async => MonthDataResponse(ok: true, rows: rows),
        ),
      ],
      child: MaterialApp(
        theme: buildAppTheme(),
        home: CategoriaPage(categoria: categoria),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  // A tela passou a ter dois grupos (Crédito e Débito) em 2026-10-01.
  testWidgets('separa os dois grupos e soma cada um', (tester) async {
    await _pump(tester, [
      _e(row: 2, categoria: 'Casa', rateio: 'Metade', valor: 200, descricao: 'LUZ'),
      _e(row: 3, categoria: 'Casa', rateio: 'Julio', valor: 50, descricao: 'FURADEIRA'),
      _e(row: 4, categoria: 'Casa', origem: kOrigemDebito, rateio: 'Julio', valor: 300, descricao: 'CONTA LUZ'),
      _e(row: 5, categoria: 'Alimentação', valor: 900, descricao: 'MERCADO'),
    ], 'Casa');

    expect(tester.takeException(), isNull);

    // Grupos com contagem e subtotal no cabeçalho.
    expect(find.text('Crédito (2)'), findsOneWidget);
    expect(find.text('Débito (1)'), findsOneWidget);

    expect(find.text('LUZ'), findsOneWidget);
    expect(find.text('FURADEIRA'), findsOneWidget);
    expect(find.text('CONTA LUZ'), findsOneWidget);
    expect(find.text('MERCADO'), findsNothing);

    // Tiles: CRÉDITO 250, DÉBITO 300, TOTAL 550, COMPARTILHADO 100 (200/2).
    expect(find.text('R\$ 250,00'), findsWidgets);
    expect(find.text('R\$ 300,00'), findsWidgets);
    expect(find.text('R\$ 550,00'), findsOneWidget);
    expect(find.text('R\$ 100,00'), findsOneWidget);
  });

  testWidgets('grupo de Débito aparece no lugar certo, abaixo do Crédito',
      (tester) async {
    await _pump(tester, [
      _e(row: 2, categoria: 'Casa', descricao: 'CRED'),
      _e(row: 3, categoria: 'Casa', origem: kOrigemDebito, descricao: 'DEB'),
    ], 'Casa');

    expect(
      tester.getTopLeft(find.text('Crédito (1)')).dy,
      lessThan(tester.getTopLeft(find.text('Débito (1)')).dy),
    );
    expect(
      tester.getTopLeft(find.text('CRED')).dy,
      lessThan(tester.getTopLeft(find.text('DEB')).dy),
    );
  });

  testWidgets('cada grupo ordena por dataRef descendente', (tester) async {
    await _pump(tester, [
      _e(row: 2, descricao: 'CRED ANTIGO', dataRef: '20/12/2025 10:00'),
      _e(row: 3, descricao: 'CRED NOVO', dataRef: '05/01/2026 09:00'),
      _e(row: 4, origem: kOrigemDebito, descricao: 'DEB ANTIGO', dataRef: '20/12/2025 10:00'),
      _e(row: 5, origem: kOrigemDebito, descricao: 'DEB NOVO', dataRef: '05/01/2026 09:00'),
    ], 'Casa');

    expect(tester.getTopLeft(find.text('CRED NOVO')).dy,
        lessThan(tester.getTopLeft(find.text('CRED ANTIGO')).dy));
    expect(tester.getTopLeft(find.text('DEB NOVO')).dy,
        lessThan(tester.getTopLeft(find.text('DEB ANTIGO')).dy));
  });

  testWidgets('categoria vazia usa o traço da tabela', (tester) async {
    await _pump(tester, [
      _e(row: 2, categoria: '', descricao: 'SEM CATEGORIA'),
    ], kCategoriaVazia);

    expect(find.text('SEM CATEGORIA'), findsOneWidget);
  });

  testWidgets('cada grupo tem seu próprio vazio', (tester) async {
    await _pump(tester, [
      _e(row: 2, categoria: 'Casa', descricao: 'SO CREDITO'),
    ], 'Casa');

    expect(find.text('Crédito (1)'), findsOneWidget);
    expect(find.text('Débito (0)'), findsOneWidget);
    expect(find.text('Sem lançamentos de débito nesta categoria.'),
        findsOneWidget);
    expect(find.text('Sem lançamentos de crédito nesta categoria.'),
        findsNothing);
  });

  testWidgets('categoria inexistente deixa os dois grupos vazios',
      (tester) async {
    await _pump(tester, [_e(row: 2, categoria: 'Casa')], 'Viagem');
    expect(find.text('Sem lançamentos de crédito nesta categoria.'),
        findsOneWidget);
    expect(find.text('Sem lançamentos de débito nesta categoria.'),
        findsOneWidget);
  });
}
