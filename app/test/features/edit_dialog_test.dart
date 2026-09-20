import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hook_finance/api/client.dart';
import 'package:hook_finance/api/config.dart';
import 'package:hook_finance/api/endpoints.dart';
import 'package:hook_finance/core/origem.dart';
import 'package:hook_finance/core/types.dart';
import 'package:hook_finance/features/lancamento/edit_dialog.dart';
import 'package:hook_finance/theme/theme.dart';

Entry _entry({String rateio = 'Julio', String origem = kOrigemCredito}) => Entry(
      row: 42,
      data: '06/10/2026',
      dataRef: '18/09/2026 18:17',
      descricao: 'CLARO INTERNET',
      valor: 110,
      origem: origem,
      categoria: 'Contas',
      rateio: rateio,
      banco: '',
      parcela: '',
      acerto: '',
    );

Future<void> _open(WidgetTester tester, Entry e) async {
  tester.view.physicalSize = const Size(412, 915);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final api = ApiEndpoints(ApiClient(const ApiConfig(token: 't')));
  await tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(),
      home: Scaffold(
        body: EditDialog(
          entry: e,
          rowsForCategoriaSuggestions: const [],
          api: api,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

// A fonte default do flutter_test desenha cada glifo como um quadrado do
// tamanho da fonte, o que estoura a largura do item "Metade (compartilhado)"
// do dropdown. Com fonte real cabe (medido em 2026-09-18), então o overflow é
// artefato do ambiente de teste — qualquer outra exceção é real.
void _semErroReal(WidgetTester tester) {
  final err = tester.takeException();
  if (err == null) return;
  if (err.toString().contains('RenderFlex overflowed')) return;
  fail('exceção inesperada: $err');
}

void main() {
  testWidgets('abre com rateio válido', (tester) async {
    await _open(tester, _entry(rateio: 'Julio'));
    _semErroReal(tester);
    expect(find.text('Julio'), findsWidgets);
  });

  // O dropdown tem itens fixos; um valor fora do enum na planilha (digitado à
  // mão, como o "Júlio" acentuado encontrado em 2026-09-20) fazia o
  // DropdownButtonFormField estourar e o modal não abria — a linha ficava
  // ineditável justamente no app que serviria para corrigi-la.
  testWidgets('rateio legado fora do enum abre com prefixo (?)', (tester) async {
    await _open(tester, _entry(rateio: 'Júlio'));
    _semErroReal(tester);
    expect(find.text('(?) Júlio'), findsOneWidget);
  });

  testWidgets('origem legada fora do enum abre com prefixo (?)', (tester) async {
    await _open(tester, _entry(origem: 'Boleto'));
    _semErroReal(tester);
    expect(find.text('(?) Boleto'), findsOneWidget);
  });
}
