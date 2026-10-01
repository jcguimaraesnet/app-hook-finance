import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hook_finance/core/origem.dart';
import 'package:hook_finance/core/rules/acerto_total.dart';
import 'package:hook_finance/core/rateio.dart';
import 'package:hook_finance/core/types.dart';
import 'package:hook_finance/features/acerto/acerto_page.dart';
import 'package:hook_finance/state/data_providers.dart';
import 'package:hook_finance/theme/theme.dart';

Entry _e({
  required int row,
  required String origem,
  required String rateio,
  required double valor,
  String acerto = '',
  String descricao = 'X',
}) =>
    Entry(
      row: row,
      data: '06/11/2026',
      dataRef: '18/09/2026 10:00',
      descricao: descricao,
      valor: valor,
      origem: origem,
      categoria: 'Casa',
      rateio: rateio,
      banco: '',
      parcela: '',
      acerto: acerto,
    );

final _rows = [
  _e(row: 2, origem: kOrigemCredito, rateio: kRateioCompartilhado, valor: 200),
  _e(row: 3, origem: kOrigemCredito, rateio: 'Dani', valor: 60),
  _e(row: 4, origem: kOrigemDebito, rateio: kRateioCompartilhado, valor: 400, acerto: 'Sim'),
  _e(row: 5, origem: kOrigemDebito, rateio: 'Dani', valor: 70, descricao: 'SEM MARCA'),
  _e(row: 6, origem: kOrigemDebito, rateio: 'Dani', valor: 30, acerto: 'Sim', descricao: 'COM MARCA'),
];

/// A fonte do flutter_test desenha cada glifo como um quadrado e estoura a
/// linha do cabeçalho do card ("Diferença R\$ X"). Com fonte real cabe.
void _semErroReal(WidgetTester tester) {
  while (true) {
    final err = tester.takeException();
    if (err == null) return;
    if (err.toString().contains('RenderFlex overflowed')) continue;
    fail('exceção inesperada: $err');
  }
}

void main() {
  // O número grande do topo e o "Total Pessoal" do card são o mesmo valor. Já
  // divergiram (4.566,65 em cima, 7.883,06 embaixo) por estarem calculados em
  // dois lugares; agora os dois vêm de acertoBreakdown.
  testWidgets('topo e Total Pessoal mostram o mesmo número', (tester) async {
    tester.view.physicalSize = const Size(412, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          monthDataProvider.overrideWith((ref, month) async =>
              MonthDataResponse(ok: true, month: '06/11/2026', rows: _rows)),
        ],
        child: MaterialApp(
          theme: buildAppTheme(),
          home: const Scaffold(body: AcertoPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    _semErroReal(tester);

    // Dani: créd.compart 100 + créd.pess 60 + déb.compart 200 + déb.pess 100.
    final esperado = acertoBreakdown(_rows, Person.dani).total;
    expect(esperado, 460);
    expect(find.text('R\$ 460,00'), findsOneWidget); // topo
    expect(find.text('460,00'), findsOneWidget); // Total Pessoal do card
  });

  testWidgets('débito sem acerto=Sim aparece na lista', (tester) async {
    tester.view.physicalSize = const Size(412, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          monthDataProvider.overrideWith((ref, month) async =>
              MonthDataResponse(ok: true, month: '06/11/2026', rows: _rows)),
        ],
        child: MaterialApp(
          theme: buildAppTheme(),
          home: const Scaffold(body: AcertoPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    _semErroReal(tester);

    expect(find.text('SEM MARCA'), findsOneWidget);
    expect(find.text('COM MARCA'), findsOneWidget);
  });
}
