import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hook_finance/core/origem.dart';
import 'package:hook_finance/core/rules/acerto_total.dart';
import 'package:hook_finance/core/rules/diff_calculation.dart';
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
  String categoria = 'Casa',
}) =>
    Entry(
      row: row,
      data: '06/11/2026',
      dataRef: '18/09/2026 10:00',
      descricao: descricao,
      valor: valor,
      origem: origem,
      categoria: categoria,
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
  _e(row: 7, origem: kOrigemDebito, rateio: 'Dani', valor: 40, categoria: 'Pessoal', descricao: 'DIZIMO'),
  _e(row: 8, origem: kOrigemDebito, rateio: 'Julio', valor: 60, descricao: 'CONDOMINIO'),
  _e(row: 9, origem: kOrigemDebito, rateio: 'Julio', valor: 500, categoria: 'Pessoal', descricao: 'PREVIDENCIA'),
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
  // O topo mostra o que a pessoa TRANSFERE (reembolsos + crédito) e o rodapé o
  // que ela GASTOU (mais o débito). Divergem de propósito desde 2026-10-02 —
  // antes eram o mesmo valor e divergiram por acidente (4.566,65 em cima,
  // 7.883,06 embaixo), por isso os dois saem de acertoBreakdown.
  testWidgets('topo é reembolsos + crédito; rodapé é o total', (tester) async {
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

    // Dani: créd.compart 100 + créd.pess 60 = 160 no topo; mais déb.compart 200
    // e déb.pessoal 140 = 500 no rodapé. Sem reembolso nestas linhas.
    final b = acertoBreakdown(_rows, Person.dani);
    expect(b.reembolso, 0);
    expect(b.transferencia, 160);
    expect(b.total, 500);
    expect(find.text('R\$ 160,00'), findsOneWidget); // topo
    expect(find.text('500,00'), findsOneWidget); // Total Pessoal do card
  });

  // Tabela simétrica desde 2026-10-02: Reembolsos, Crédito ×2 e Débito ×2,
  // cada bloco fechado pela sua faixa de subtotal.
  testWidgets('as linhas agrupadoras, os subtotais e os filhos',
      (tester) async {
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

    expect(find.text('Reembolsos'), findsOneWidget);
    expect(find.text('Crédito (compartilhado)'), findsOneWidget);
    expect(find.text('Crédito (pessoal)'), findsOneWidget);
    expect(find.text('Débito (compartilhado)'), findsOneWidget);
    expect(find.text('Débito (pessoal)'), findsOneWidget);
    expect(find.text('Subtotal reembolsos'), findsOneWidget);
    expect(find.text('Subtotal crédito'), findsOneWidget);
    expect(find.text('Subtotal débito'), findsOneWidget);

    // Contraídas por padrão (2026-10-02): os filhos não estão na tela.
    expect(find.text('DIZIMO'), findsNothing);
    expect(find.text('70,00'), findsNothing);

    // Todo o débito da Dani num grupo só: 70 + 30 + 40 = 140.
    expect(find.text('140,00'), findsOneWidget);
    // Subtotais: crédito 160, débito 340, e os dois somam o total.
    expect(find.text('160,00'), findsOneWidget);
    expect(find.text('340,00'), findsOneWidget);

    // Abrir o grupo revela os lançamentos, que somam o subtotal.
    await tester.tap(find.text('Débito (pessoal)'));
    await tester.pumpAndSettle();
    _semErroReal(tester);
    expect(find.text('70,00'), findsOneWidget);
    expect(find.text('30,00'), findsOneWidget);
    expect(find.text('DIZIMO'), findsOneWidget);
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

    await tester.tap(find.text('Débito (pessoal)'));
    await tester.pumpAndSettle();
    _semErroReal(tester);

    expect(find.text('SEM MARCA'), findsOneWidget);
    expect(find.text('COM MARCA'), findsOneWidget);
  });

  // O pill ignora a categoria Pessoal. De 2026-10-01 a 2026-10-02 havia uma
  // linha "Débito (outros)" com exatamente esse recorte; ela saiu na
  // simetrização, mas a regra do dinheiro ficou.
  testWidgets('a Diferença ignora a categoria Pessoal', (tester) async {
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

    // Dani (card default): outros = 70 + 30 = 100. Júlio: outros = 60.
    // As de categoria Pessoal (40 e 500) ficam fora.
    expect(diffCalculation(_rows, Person.dani), 40);
    expect(find.text('R\$ 40,00'), findsOneWidget); // pill do header
  });

  // 2026-10-02: col J passou a dizer quem reembolsa. No card da Dani, as linhas
  // marcadas "Julio" saem dos grupos normais e formam o primeiro bloco.
  testWidgets('reembolso sai do grupo de débito e vai para Reembolsos',
      (tester) async {
    tester.view.physicalSize = const Size(412, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final comReembolso = [
      ..._rows,
      _e(row: 10, origem: kOrigemDebito, rateio: 'Dani', valor: 250, acerto: 'Julio', descricao: 'CONDOMINIO DEV'),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          monthDataProvider.overrideWith((ref, month) async => MonthDataResponse(
              ok: true, month: '06/11/2026', rows: comReembolso)),
        ],
        child: MaterialApp(
          theme: buildAppTheme(),
          home: const Scaffold(body: AcertoPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    _semErroReal(tester);

    final b = acertoBreakdown(comReembolso, Person.dani);
    expect(b.reembolso, 250);
    // O topo soma o reembolso ao crédito; o débito segue fora dele.
    expect(b.transferencia, 410); // 250 + 160
    // Saiu do débito pessoal, que continua 140.
    expect(b.debitoPessoal, 140);
    // E o total cresce com a linha nova: a regrouping não perde dinheiro.
    expect(b.total, 750);
    // Contraído: só o cabeçalho do grupo e a faixa de subtotal mostram o valor.
    expect(find.text('CONDOMINIO DEV'), findsNothing);
    expect(find.text('250,00'), findsNWidgets(2));

    await tester.tap(find.text('Reembolsos'));
    await tester.pumpAndSettle();
    _semErroReal(tester);
    expect(find.text('CONDOMINIO DEV'), findsOneWidget);
    expect(find.text('250,00'), findsNWidgets(3));
  });
}
