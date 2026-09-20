import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hook_finance/core/origem.dart';
import 'package:hook_finance/core/types.dart';
import 'package:hook_finance/features/despesas_fixas/despesas_fixas_page.dart';
import 'package:hook_finance/features/despesas_fixas/fixed_expense_dialog.dart';
import 'package:hook_finance/state/data_providers.dart';
import 'package:hook_finance/theme/theme.dart';

Map<String, dynamic> _json({
  required int row,
  int dia = 10,
  String descricao = 'CONDOMINIO',
  double valor = 500,
  String origem = kOrigemDebito,
  String rateio = 'Metade',
  String acerto = '',
  String invalid = '',
}) =>
    {
      'row': row,
      'dia': dia,
      'descricao': descricao,
      'valor': valor,
      'origem': origem,
      'categoria': 'Contas',
      'rateio': rateio,
      'acerto': acerto,
      'invalid': invalid,
    };

Future<void> _pump(WidgetTester tester, List<Map<String, dynamic>> rows) async {
  tester.view.physicalSize = const Size(412, 915);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        fixedExpensesProvider.overrideWith(
          (ref) async => FixedExpensesResponse.fromJson({
            'ok': true,
            'rows': rows,
          }),
        ),
      ],
      child: MaterialApp(
        theme: buildAppTheme(),
        home: const DespesasFixasPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('lista as linhas e soma o total mensal', (tester) async {
    await _pump(tester, [
      _json(row: 2, descricao: 'CONDOMINIO', valor: 500),
      _json(row: 3, descricao: 'INTERNET', valor: 110, rateio: 'Julio'),
      _json(row: 4, descricao: 'GAS', valor: 120.42, acerto: 'Sim'),
    ]);

    expect(find.text('CONDOMINIO'), findsOneWidget);
    expect(find.text('INTERNET'), findsOneWidget);
    expect(find.text('GAS'), findsOneWidget);
    expect(find.text('R\$ 730,42'), findsOneWidget); // total mensal
    expect(find.text('3'), findsOneWidget); // contagem de linhas
  });

  // O motivo de o endpoint de leitura não lançar como o loadFixedExpenses_ do
  // webhook: a linha quebrada precisa aparecer, senão a tela que serve para
  // consertá-la seria a primeira a sumir.
  testWidgets('linha inválida aparece com o motivo e um aviso no topo',
      (tester) async {
    await _pump(tester, [
      _json(row: 2, descricao: 'CONDOMINIO', valor: 500),
      _json(
        row: 3,
        descricao: 'LUZ',
        dia: 32,
        invalid: 'dia inválido (32)',
      ),
    ]);

    expect(find.text('LUZ'), findsOneWidget);
    expect(find.text('dia inválido (32)'), findsOneWidget);
    expect(
      find.textContaining('travam a criação da próxima fatura'),
      findsNothing,
    );
    expect(
      find.textContaining('trava a criação da próxima fatura'),
      findsOneWidget,
    );
  });

  testWidgets('plural do aviso com mais de uma inválida', (tester) async {
    await _pump(tester, [
      _json(row: 2, invalid: 'descrição vazia', descricao: ''),
      _json(row: 3, invalid: 'rateio inválido ()', rateio: ''),
    ]);
    expect(
      find.textContaining('2 linhas inválidas travam'),
      findsOneWidget,
    );
  });

  testWidgets('aba vazia mostra o vazio', (tester) async {
    await _pump(tester, []);
    expect(find.text('Nenhuma despesa fixa cadastrada.'), findsOneWidget);
    expect(find.text('R\$ 0,00'), findsOneWidget);
  });

  group('valorParaEnviar', () {
    // Caso real da planilha: parcela 6x gera dízima, e o campo mostra 2 casas.
    const dizima = 379.1666666666667;
    const textoInicial = '379,17';

    test('campo intocado preserva a dízima', () {
      expect(
        valorParaEnviar(
            textoAtual: textoInicial,
            textoInicial: textoInicial,
            original: dizima),
        dizima,
      );
    });

    test('campo editado usa o texto novo', () {
      expect(
        valorParaEnviar(
            textoAtual: '400,00',
            textoInicial: textoInicial,
            original: dizima),
        400,
      );
    });

    test('editar e voltar ao texto original também preserva', () {
      expect(
        valorParaEnviar(
            textoAtual: textoInicial,
            textoInicial: textoInicial,
            original: dizima),
        dizima,
      );
    });

    test('linha nova (sem original) parseia o texto', () {
      expect(
        valorParaEnviar(
            textoAtual: '1.234,56', textoInicial: '', original: double.nan),
        1234.56,
      );
    });

    test('texto inválido vira NaN', () {
      expect(
        valorParaEnviar(
                textoAtual: 'abc', textoInicial: '', original: double.nan)
            .isNaN,
        isTrue,
      );
    });
  });
}
