import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hook_finance/core/types.dart';
import 'package:hook_finance/core/origem.dart';
import 'package:hook_finance/features/debito/debito_page.dart';
import 'package:hook_finance/state/data_providers.dart';
import 'package:hook_finance/theme/theme.dart';

Entry _e({
  required int row,
  required String origem,
  required String rateio,
  required double valor,
  required String descricao,
  String dataRef = '18/09/2026 10:00',
}) =>
    Entry(
      row: row,
      data: '06/10/2026',
      dataRef: dataRef,
      descricao: descricao,
      valor: valor,
      origem: origem,
      categoria: 'Casa',
      rateio: rateio,
      banco: '',
      parcela: '',
      acerto: '',
    );

Future<void> _pump(WidgetTester tester, List<Entry> rows) async {
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
        home: const DebitoPage(initialPerson: Person.julio),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('lista só débito da pessoa e reconcilia com o total', (
    tester,
  ) async {
    await _pump(tester, [
      _e(row: 2, origem: kOrigemCredito, rateio: 'Julio', valor: 500, descricao: 'CARTAO JULIO'),
      _e(row: 3, origem: kOrigemDebito, rateio: 'Julio', valor: 120, descricao: 'PIX JULIO'),
      _e(row: 4, origem: kOrigemDebito, rateio: 'Metade', valor: 200, descricao: 'LUZ METADE'),
      _e(row: 5, origem: kOrigemDebito, rateio: 'Dani', valor: 70, descricao: 'CONTA DANI'),
      _e(row: 6, origem: kOrigemDebito, rateio: '', valor: 999, descricao: 'SEM RATEIO'),
    ]);

    expect(tester.takeException(), isNull);

    // Entram: PIX JULIO (120) + LUZ METADE (200). Fora: cartão, Dani, sem rateio.
    expect(find.text('PIX JULIO'), findsOneWidget);
    expect(find.text('LUZ METADE'), findsOneWidget);
    expect(find.text('CARTAO JULIO'), findsNothing);
    expect(find.text('CONTA DANI'), findsNothing);
    expect(find.text('SEM RATEIO'), findsNothing);
    expect(find.text('Lançamentos de débito (2)'), findsOneWidget);

    // Sua parte = 120 + 200/2 = 220. Total cheio = 320.
    expect(find.text('SUA PARTE'), findsOneWidget);
    expect(find.text('R\$ 220,00'), findsOneWidget);
    expect(find.text('TOTAL CHEIO'), findsOneWidget);
    expect(find.text('R\$ 320,00'), findsOneWidget);
  });

  testWidgets('sem linha Metade mostra um tile só, rotulado TOTAL', (
    tester,
  ) async {
    await _pump(tester, [
      _e(row: 2, origem: kOrigemDebito, rateio: 'Julio', valor: 120, descricao: 'PIX JULIO'),
      _e(row: 3, origem: kOrigemDebito, rateio: 'Julio', valor: 80, descricao: 'LUZ JULIO'),
    ]);

    expect(tester.takeException(), isNull);
    expect(find.text('TOTAL'), findsOneWidget);
    expect(find.text('SUA PARTE'), findsNothing);
    expect(find.text('TOTAL CHEIO'), findsNothing);
    expect(find.text('R\$ 200,00'), findsOneWidget);
  });

  testWidgets('ordena por dataRef descendente, com o ano contando', (
    tester,
  ) async {
    await _pump(tester, [
      _e(row: 2, origem: kOrigemDebito, rateio: 'Julio', valor: 10, descricao: 'DEZEMBRO', dataRef: '20/12/2025 10:00'),
      _e(row: 3, origem: kOrigemDebito, rateio: 'Julio', valor: 10, descricao: 'JANEIRO', dataRef: '05/01/2026 09:00'),
    ]);

    expect(tester.takeException(), isNull);
    final janeiro = tester.getTopLeft(find.text('JANEIRO')).dy;
    final dezembro = tester.getTopLeft(find.text('DEZEMBRO')).dy;
    expect(janeiro, lessThan(dezembro));
  });

  testWidgets('mês sem débito mostra o vazio', (tester) async {
    await _pump(tester, [
      _e(row: 2, origem: kOrigemCredito, rateio: 'Julio', valor: 500, descricao: 'SO CARTAO'),
    ]);

    expect(tester.takeException(), isNull);
    expect(find.text('Sem lançamentos de débito neste mês.'), findsOneWidget);
    expect(find.text('Lançamentos de débito (0)'), findsOneWidget);
  });
}
