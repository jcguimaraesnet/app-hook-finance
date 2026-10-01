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
  // Pós-2026-10-01 a tela acompanha a fatia Débito do Comparativo: só o débito
  // DIVIDIDO (rateio Metade). O de rateio individual soma em "Pessoal" e
  // aparece em Despesas pessoais.
  testWidgets('lista só o débito dividido e reconcilia com a fatia',
      (tester) async {
    await _pump(tester, [
      _e(row: 2, origem: kOrigemCredito, rateio: 'Julio', valor: 500, descricao: 'CARTAO JULIO'),
      _e(row: 3, origem: kOrigemDebito, rateio: 'Metade', valor: 200, descricao: 'LUZ DIVIDIDA'),
      _e(row: 4, origem: kOrigemDebito, rateio: 'Julio', valor: 120, descricao: 'PIX JULIO'),
      _e(row: 5, origem: kOrigemDebito, rateio: 'Dani', valor: 70, descricao: 'CONTA DANI'),
      _e(row: 6, origem: kOrigemDebito, rateio: '', valor: 999, descricao: 'SEM RATEIO'),
    ]);

    expect(tester.takeException(), isNull);

    expect(find.text('LUZ DIVIDIDA'), findsOneWidget);
    // Fora: cartão, o débito individual (dele e dela) e o sem rateio.
    expect(find.text('CARTAO JULIO'), findsNothing);
    expect(find.text('PIX JULIO'), findsNothing);
    expect(find.text('CONTA DANI'), findsNothing);
    expect(find.text('SEM RATEIO'), findsNothing);
    expect(find.text('Lançamentos divididos (1)'), findsOneWidget);

    // Sua parte = 200/2 = 100; total cheio = 200.
    expect(find.text('SUA PARTE'), findsOneWidget);
    expect(find.text('R\$ 100,00'), findsOneWidget);
    expect(find.text('TOTAL CHEIO'), findsOneWidget);
    // Aparece duas vezes: no tile e na própria linha do lançamento.
    expect(find.text('R\$ 200,00'), findsNWidgets(2));
  });

  testWidgets('ordena por dataRef descendente, com o ano contando',
      (tester) async {
    await _pump(tester, [
      _e(row: 2, origem: kOrigemDebito, rateio: 'Metade', valor: 10, descricao: 'DEZEMBRO', dataRef: '20/12/2025 10:00'),
      _e(row: 3, origem: kOrigemDebito, rateio: 'Metade', valor: 10, descricao: 'JANEIRO', dataRef: '05/01/2026 09:00'),
    ]);

    expect(tester.takeException(), isNull);
    expect(
      tester.getTopLeft(find.text('JANEIRO')).dy,
      lessThan(tester.getTopLeft(find.text('DEZEMBRO')).dy),
    );
  });

  // O caso comum na planilha: nenhum débito é dividido, então a tela fica
  // vazia — e isso é verdade, não bug. O vazio aponta para onde o dinheiro está.
  testWidgets('mês só com débito individual mostra o vazio explicativo',
      (tester) async {
    await _pump(tester, [
      _e(row: 2, origem: kOrigemDebito, rateio: 'Julio', valor: 120, descricao: 'PIX JULIO'),
    ]);

    expect(tester.takeException(), isNull);
    expect(find.text('Lançamentos divididos (0)'), findsOneWidget);
    expect(find.textContaining('Despesas pessoais'), findsOneWidget);
    expect(find.text('PIX JULIO'), findsNothing);
  });
}
