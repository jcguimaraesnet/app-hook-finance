import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hook_finance/core/origem.dart';
import 'package:hook_finance/core/types.dart';
import 'package:hook_finance/features/compart/compart_page.dart';
import 'package:hook_finance/state/data_providers.dart';
import 'package:hook_finance/state/nav_provider.dart';
import 'package:hook_finance/theme/theme.dart';

Entry _e({
  required int row,
  String origem = kOrigemCredito,
  String rateio = 'Metade',
  double valor = 100,
  String categoria = 'Casa',
}) =>
    Entry(
      row: row,
      data: '06/11/2026',
      dataRef: '18/09/2026 10:00',
      descricao: 'X',
      valor: valor,
      origem: origem,
      categoria: categoria,
      rateio: rateio,
      banco: '',
      parcela: '',
      acerto: '',
    );

final _rows = [
  _e(row: 2, origem: kOrigemCredito, rateio: 'Metade', valor: 200),
  _e(row: 3, origem: kOrigemCredito, rateio: 'Julio', valor: 50),
  _e(row: 4, origem: kOrigemDebito, rateio: 'Metade', valor: 400),
  _e(row: 5, origem: kOrigemDebito, rateio: 'Dani', valor: 70),
];

Future<ProviderContainer> _pump(WidgetTester tester, {String? filtro}) async {
  tester.view.physicalSize = const Size(412, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final container = ProviderContainer(overrides: [
    monthDataProvider.overrideWith((ref, month) async =>
        MonthDataResponse(ok: true, month: '06/11/2026', rows: _rows)),
    compartOrigemFilterProvider.overrideWith((ref) => filtro),
  ]);
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(theme: buildAppTheme(), home: const CompartPage()),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  // Sem seleção o compartilhado soma as duas origens; com um tile marcado,
  // só a origem dele. Spec: docs/specs/pages/compart.md
  testWidgets('sem filtro soma as duas origens', (tester) async {
    await _pump(tester);
    // Metade: 200 (crédito) + 400 (débito) = 600; /2 = 300.
    expect(find.text('R\$ 600,00'), findsOneWidget);
    expect(find.text('R\$ 300,00'), findsOneWidget);
    expect(find.text('COMPARTILHADO'), findsOneWidget);
  });

  testWidgets('filtro de Crédito conta só o crédito', (tester) async {
    await _pump(tester, filtro: kOrigemCredito);
    expect(find.text('R\$ 200,00'), findsWidgets); // compartilhado
    expect(find.text('R\$ 100,00'), findsOneWidget); // /2
    expect(find.text('COMPARTILHADO CRÉDITO'), findsOneWidget);
  });

  testWidgets('filtro de Débito conta só o débito', (tester) async {
    await _pump(tester, filtro: kOrigemDebito);
    expect(find.text('R\$ 400,00'), findsWidgets);
    expect(find.text('R\$ 200,00'), findsWidgets); // /2
    expect(find.text('COMPARTILHADO DÉBITO'), findsOneWidget);
  });

  testWidgets('tocar no tile marca e tocar de novo desmarca', (tester) async {
    final container = await _pump(tester);
    expect(container.read(compartOrigemFilterProvider), isNull);

    await tester.tap(find.text('TOTAL DÉBITO'));
    await tester.pumpAndSettle();
    expect(container.read(compartOrigemFilterProvider), kOrigemDebito);

    await tester.tap(find.text('TOTAL DÉBITO'));
    await tester.pumpAndSettle();
    expect(container.read(compartOrigemFilterProvider), isNull);
  });

  testWidgets('marcar um tile desmarca o outro', (tester) async {
    final container = await _pump(tester, filtro: kOrigemDebito);
    await tester.tap(find.text('TOTAL CRÉDITO'));
    await tester.pumpAndSettle();
    expect(container.read(compartOrigemFilterProvider), kOrigemCredito);
  });
}
