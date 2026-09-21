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
  testWidgets('lista só a categoria e reconcilia com os dois totais',
      (tester) async {
    await _pump(tester, [
      _e(row: 2, categoria: 'Casa', rateio: 'Metade', valor: 200, descricao: 'LUZ'),
      _e(row: 3, categoria: 'Casa', rateio: 'Julio', valor: 50, descricao: 'FURADEIRA'),
      _e(row: 4, categoria: 'Alimentação', valor: 900, descricao: 'MERCADO'),
      _e(row: 5, categoria: 'Casa', origem: kOrigemDebito, valor: 777, descricao: 'CONTA LUZ'),
    ], 'Casa');

    expect(tester.takeException(), isNull);
    expect(find.text('LUZ'), findsOneWidget);
    expect(find.text('FURADEIRA'), findsOneWidget);
    expect(find.text('MERCADO'), findsNothing);
    expect(find.text('CONTA LUZ'), findsNothing);
    expect(find.text('Lançamentos (2)'), findsOneWidget);
    expect(find.text('R\$ 250,00'), findsOneWidget); // total cheio
    expect(find.text('R\$ 100,00'), findsOneWidget); // compartilhado (200/2)
  });

  testWidgets('ordena por dataRef descendente', (tester) async {
    await _pump(tester, [
      _e(row: 2, descricao: 'ANTIGO', dataRef: '20/12/2025 10:00'),
      _e(row: 3, descricao: 'RECENTE', dataRef: '05/01/2026 09:00'),
    ], 'Casa');

    expect(
      tester.getTopLeft(find.text('RECENTE')).dy,
      lessThan(tester.getTopLeft(find.text('ANTIGO')).dy),
    );
  });

  testWidgets('categoria vazia usa o traço da tabela', (tester) async {
    await _pump(tester, [
      _e(row: 2, categoria: '', descricao: 'SEM CATEGORIA'),
    ], kCategoriaVazia);

    expect(find.text('SEM CATEGORIA'), findsOneWidget);
  });

  testWidgets('categoria sem lançamentos mostra o vazio', (tester) async {
    await _pump(tester, [_e(row: 2, categoria: 'Casa')], 'Viagem');
    expect(find.text('Sem lançamentos nesta categoria.'), findsOneWidget);
    expect(find.text('Lançamentos (0)'), findsOneWidget);
  });
}
