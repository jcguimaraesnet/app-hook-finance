import 'package:flutter_test/flutter_test.dart';
import 'package:hook_finance/core/origem.dart';
import 'package:hook_finance/core/rules/categoria_rows.dart';
import 'package:hook_finance/core/types.dart';

ExpenseRow _r({
  String origem = kOrigemCredito,
  String categoria = 'Alimentação',
  String rateio = 'Metade',
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
        categoriaRowsForMonth(rows, 'Casa').map((r) => r.descricao),
        ['a', 'b'],
      );
    });

    test('o drill-down da categoria vazia acha as linhas sem categoria', () {
      final rows = [
        _r(categoria: '', descricao: 'sem'),
        _r(categoria: 'Casa', descricao: 'com'),
      ];
      expect(
        categoriaRowsForMonth(rows, kCategoriaVazia).map((r) => r.descricao),
        ['sem'],
      );
    });

    test('categoria inexistente retorna vazio', () {
      expect(categoriaRowsForMonth([_r()], 'Viagem'), isEmpty);
    });
  });

  // A tela é aberta a partir de um número da tabela do Compart, então os dois
  // totais precisam bater exatamente com a linha clicada.
  group('reconciliação com a tabela do Compart', () {
    final rows = [
      _r(categoria: 'Casa', rateio: 'Metade', valor: 200),
      _r(categoria: 'Casa', rateio: 'Julio', valor: 50),
      _r(categoria: 'Casa', rateio: '', valor: 30),
      _r(categoria: 'Casa', origem: kOrigemDebito, rateio: 'Metade', valor: 999),
      _r(categoria: 'Alimentação', rateio: 'Metade', valor: 80),
    ];

    test('total é o cheio, compart é metade só das linhas Metade', () {
      final t = categoriaTotais(categoriaRowsForMonth(rows, 'Casa'));
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
          categoriaTotais(categoriaRowsForMonth(rows, entry.key)).total,
          entry.value,
          reason: 'categoria ${entry.key} não fecha',
        );
      }
    });

    test('sem linhas Metade, compart é zero', () {
      final t = categoriaTotais(
          categoriaRowsForMonth([_r(categoria: 'Casa', rateio: 'Julio')], 'Casa'));
      expect(t.total, 100);
      expect(t.compart, 0);
    });
  });
}
