import 'package:flutter_test/flutter_test.dart';
import 'package:hook_finance/core/rules/bucket_deltas.dart';
import 'package:hook_finance/core/origem.dart';
import 'package:hook_finance/core/rules/debito_rows.dart';
import 'package:hook_finance/core/types.dart';

ExpenseRow _r({
  required String origem,
  required String rateio,
  required double valor,
  String descricao = 'x',
}) =>
    ExpenseRow(
      data: '06/10/2026',
      dataRef: '18/09/2026 10:00',
      descricao: descricao,
      valor: valor,
      origem: origem,
      categoria: 'Casa',
      rateio: rateio,
      banco: '',
      parcela: '',
      acerto: '',
    );

void main() {
  group('debitoRowsForPerson', () {
    test('exclui Crédito e mantém Débito', () {
      final rows = [
        _r(origem: kOrigemCredito, rateio: 'Julio', valor: 100, descricao: 'cartão'),
        _r(origem: kOrigemDebito, rateio: 'Julio', valor: 50, descricao: 'contas'),
        _r(origem: kOrigemDebito, rateio: 'Julio', valor: 30, descricao: 'pix'),
        _r(origem: kOrigemDebito, rateio: 'Julio', valor: 20, descricao: 'emp'),
        _r(origem: kOrigemDebito, rateio: 'Julio', valor: 10, descricao: 'pes'),
      ];
      expect(
        debitoRowsForPerson(rows, Person.julio).map((r) => r.descricao),
        ['contas', 'pix', 'emp', 'pes'],
      );
    });

    test('exclui rateio que não toca a pessoa', () {
      final rows = [
        _r(origem: kOrigemDebito, rateio: 'Dani', valor: 50, descricao: 'dani'),
        _r(origem: kOrigemDebito, rateio: '', valor: 50, descricao: 'vazio'),
        _r(origem: kOrigemDebito, rateio: 'Alzira', valor: 50, descricao: 'alzira'),
        _r(origem: kOrigemDebito, rateio: 'Julio', valor: 50, descricao: 'julio'),
      ];
      expect(
        debitoRowsForPerson(rows, Person.julio).map((r) => r.descricao),
        ['julio'],
      );
    });

    test('Metade aparece para as duas pessoas', () {
      final rows = [_r(origem: kOrigemDebito, rateio: 'Metade', valor: 80)];
      expect(debitoRowsForPerson(rows, Person.julio), hasLength(1));
      expect(debitoRowsForPerson(rows, Person.dani), hasLength(1));
      expect(debitoShareForPerson(rows, Person.julio), 40);
    });

    test('preserva a ordem de entrada', () {
      final rows = [
        _r(origem: kOrigemDebito, rateio: 'Julio', valor: 1, descricao: 'a'),
        _r(origem: kOrigemDebito, rateio: 'Metade', valor: 2, descricao: 'b'),
        _r(origem: kOrigemDebito, rateio: 'Julio', valor: 3, descricao: 'c'),
      ];
      expect(
        debitoRowsForPerson(rows, Person.julio).map((r) => r.descricao),
        ['a', 'b', 'c'],
      );
    });

    test('rows vazio retorna vazio', () {
      expect(debitoRowsForPerson(const <ExpenseRow>[], Person.julio), isEmpty);
      expect(debitoShareForPerson(const <ExpenseRow>[], Person.julio), 0);
    });

    test('estorno negativo entra normalmente', () {
      final rows = [_r(origem: kOrigemDebito, rateio: 'Julio', valor: -25)];
      expect(debitoRowsForPerson(rows, Person.julio), hasLength(1));
      expect(debitoShareForPerson(rows, Person.julio), -25);
    });

    test('valor zero fica de fora (degenerado)', () {
      final rows = [_r(origem: kOrigemDebito, rateio: 'Julio', valor: 0)];
      expect(debitoRowsForPerson(rows, Person.julio), isEmpty);
    });
  });

  // O motivo da regra existir: a tela Débito é aberta a partir de um número do
  // card Comparativo, então a lista precisa somar exatamente aquele número.
  group('reconciliação com o card Comparativo', () {
    final rows = [
      _r(origem: kOrigemCredito, rateio: 'Julio', valor: 500),
      _r(origem: kOrigemCredito, rateio: 'Metade', valor: 300),
      _r(origem: kOrigemDebito, rateio: 'Julio', valor: 120),
      _r(origem: kOrigemDebito, rateio: 'Metade', valor: 200),
      _r(origem: kOrigemDebito, rateio: 'Dani', valor: 70),
      _r(origem: kOrigemDebito, rateio: 'Metade', valor: 90),
      _r(origem: kOrigemDebito, rateio: '', valor: 999),
      _r(origem: kOrigemDebito, rateio: 'Alzira', valor: 777),
    ];

    for (final person in Person.values) {
      test('soma da lista == bucket debito (${person.name})', () {
        expect(
          debitoShareForPerson(rows, person),
          bucketsForPerson(rows, person).debito,
        );
      });
    }

    test('linhas ignoradas pelo bucket também somem da lista', () {
      final descricoes =
          debitoRowsForPerson(rows, Person.julio).map((r) => r.descricao);
      expect(descricoes, everyElement('x'));
      // 120 (Julio) + 200/2 (Metade) + 90/2 (Metade) = 265
      expect(debitoShareForPerson(rows, Person.julio), 265);
    });
  });
}
