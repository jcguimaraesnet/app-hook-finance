import 'package:flutter_test/flutter_test.dart';
import 'package:hook_finance/core/origem.dart';
import 'package:hook_finance/core/rules/categoria_rows.dart';
import 'package:hook_finance/core/rateio.dart';
import 'package:hook_finance/core/types.dart';

ExpenseRow _r({
  String origem = kOrigemCredito,
  String categoria = 'Alimentação',
  String rateio = kRateioCompartilhado,
  double valor = 100,
  String descricao = 'x',
}) =>
    ExpenseRow(
      data: '06/10/2026',
      dataRef: '18/09/2026 10:00',
      descricao: descricao,
      valor: valor,
      origem: origem,
      categoria: categoria,
      rateio: rateio,
      banco: '',
      parcela: '',
      acerto: '',
    );

void main() {
  group('categoriaLabel', () {
    test('categoria vazia vira o traço que a tabela mostra', () {
      expect(categoriaLabel(_r(categoria: '')), kCategoriaVazia);
      expect(categoriaLabel(_r(categoria: 'Casa')), 'Casa');
    });
  });

  group('categoriaRowsForMonth', () {
    test('filtra por categoria e só Crédito', () {
      final rows = [
        _r(categoria: 'Casa', descricao: 'a'),
        _r(categoria: 'Casa', descricao: 'b'),
        _r(categoria: 'Alimentação', descricao: 'c'),
        _r(categoria: 'Casa', origem: kOrigemDebito, descricao: 'd'),
      ];
      expect(
        categoriaRowsForMonth(rows, 'Casa', origem: kOrigemCredito).map((r) => r.descricao),
        ['a', 'b'],
      );
    });

    test('o drill-down da categoria vazia acha as linhas sem categoria', () {
      final rows = [
        _r(categoria: '', descricao: 'sem'),
        _r(categoria: 'Casa', descricao: 'com'),
      ];
      expect(
        categoriaRowsForMonth(rows, kCategoriaVazia, origem: kOrigemCredito).map((r) => r.descricao),
        ['sem'],
      );
    });

    test('categoria inexistente retorna vazio', () {
      expect(categoriaRowsForMonth([_r()], 'Viagem', origem: kOrigemCredito), isEmpty);
    });
  });

  // A tela é aberta a partir de um número da tabela do Compart, então os dois
  // totais precisam bater exatamente com a linha clicada.
  group('reconciliação com a tabela do Compart', () {
    final rows = [
      _r(categoria: 'Casa', rateio: kRateioCompartilhado, valor: 200),
      _r(categoria: 'Casa', rateio: 'Julio', valor: 50),
      _r(categoria: 'Casa', rateio: '', valor: 30),
      _r(categoria: 'Casa', origem: kOrigemDebito, rateio: kRateioCompartilhado, valor: 999),
      _r(categoria: 'Alimentação', rateio: kRateioCompartilhado, valor: 80),
    ];

    test('total é o cheio, compart é metade só das linhas Metade', () {
      final t = categoriaTotais(categoriaRowsForMonth(rows, 'Casa', origem: kOrigemCredito));
      expect(t.total, 280); // 200 + 50 + 30, sem o Débito
      expect(t.compart, 100); // 200/2
    });

    test('replica o agrupamento do Compart para todas as categorias', () {
      // Mesma conta que a página faz ao montar a tabela.
      final byCat = <String, double>{};
      for (final r in rows.where((r) => r.origem == kOrigemCredito)) {
        byCat[categoriaLabel(r)] = (byCat[categoriaLabel(r)] ?? 0) + r.valor;
      }
      for (final entry in byCat.entries) {
        expect(
          categoriaTotais(categoriaRowsForMonth(rows, entry.key, origem: kOrigemCredito)).total,
          entry.value,
          reason: 'categoria ${entry.key} não fecha',
        );
      }
    });

    test('sem linhas Metade, compart é zero', () {
      final t = categoriaTotais(
          categoriaRowsForMonth([_r(categoria: 'Casa', rateio: 'Julio')], 'Casa',
              origem: kOrigemCredito));
      expect(t.total, 100);
      expect(t.compart, 0);
    });
  });

  // A tela de categoria passou a mostrar dois grupos (2026-10-01). O recorte por
  // origem é explícito na chamada justamente para os dois não se misturarem.
  group('grupo de Débito', () {
    final rows = [
      _r(categoria: 'Casa', origem: kOrigemCredito, valor: 100, descricao: 'cred'),
      _r(categoria: 'Casa', origem: kOrigemDebito, valor: 300, descricao: 'deb'),
      _r(categoria: 'Casa', origem: kOrigemDebito, rateio: 'Julio', valor: 50, descricao: 'deb2'),
      _r(categoria: 'Alimentação', origem: kOrigemDebito, valor: 900, descricao: 'outra'),
    ];

    test('separa as duas origens da mesma categoria', () {
      expect(
        categoriaRowsForMonth(rows, 'Casa', origem: kOrigemCredito)
            .map((r) => r.descricao),
        ['cred'],
      );
      expect(
        categoriaRowsForMonth(rows, 'Casa', origem: kOrigemDebito)
            .map((r) => r.descricao),
        ['deb', 'deb2'],
      );
    });

    test('o tile de Crédito segue igual à linha da tabela do Compart', () {
      // A tabela do Compart é só de Crédito; incluir Débito aqui faria o
      // detalhamento divergir do número que foi clicado.
      final t = categoriaTotais(
          categoriaRowsForMonth(rows, 'Casa', origem: kOrigemCredito));
      expect(t.total, 100);
    });

    test('compartilhado de cada grupo conta só as linhas Metade', () {
      final td = categoriaTotais(
          categoriaRowsForMonth(rows, 'Casa', origem: kOrigemDebito));
      expect(td.total, 350); // 300 + 50
      expect(td.compart, 150); // só a de Metade, 300/2
    });
  });
}
