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
    test('mantém só Débito com rateio Metade', () {
      final rows = [
        _r(origem: kOrigemCredito, rateio: 'Metade', valor: 100, descricao: 'cartão dividido'),
        _r(origem: kOrigemCredito, rateio: 'Julio', valor: 100, descricao: 'cartão dele'),
        _r(origem: kOrigemDebito, rateio: 'Metade', valor: 50, descricao: 'luz dividida'),
        _r(origem: kOrigemDebito, rateio: 'Julio', valor: 30, descricao: 'pix dele'),
      ];
      expect(
        debitoRowsForPerson(rows, Person.julio).map((r) => r.descricao),
        ['luz dividida'],
      );
    });

    test('rateio que não toca ninguém fica de fora', () {
      final rows = [
        _r(origem: kOrigemDebito, rateio: '', valor: 50, descricao: 'vazio'),
        _r(origem: kOrigemDebito, rateio: 'Alzira', valor: 50, descricao: 'alzira'),
        _r(origem: kOrigemDebito, rateio: 'Metade', valor: 50, descricao: 'metade'),
      ];
      expect(
        debitoRowsForPerson(rows, Person.julio).map((r) => r.descricao),
        ['metade'],
      );
    });

    test('a mesma linha aparece para as duas pessoas, pela metade', () {
      final rows = [_r(origem: kOrigemDebito, rateio: 'Metade', valor: 80)];
      expect(debitoRowsForPerson(rows, Person.julio), hasLength(1));
      expect(debitoRowsForPerson(rows, Person.dani), hasLength(1));
      expect(debitoShareForPerson(rows, Person.julio), 40);
      expect(debitoShareForPerson(rows, Person.dani), 40);
    });

    test('preserva a ordem de entrada', () {
      final rows = [
        _r(origem: kOrigemDebito, rateio: 'Metade', valor: 1, descricao: 'a'),
        _r(origem: kOrigemDebito, rateio: 'Julio', valor: 2, descricao: 'pulada'),
        _r(origem: kOrigemDebito, rateio: 'Metade', valor: 3, descricao: 'c'),
      ];
      expect(
        debitoRowsForPerson(rows, Person.julio).map((r) => r.descricao),
        ['a', 'c'],
      );
    });

    test('rows vazio retorna vazio', () {
      expect(debitoRowsForPerson(const <ExpenseRow>[], Person.julio), isEmpty);
      expect(debitoShareForPerson(const <ExpenseRow>[], Person.julio), 0);
    });

    test('estorno negativo entra normalmente', () {
      final rows = [_r(origem: kOrigemDebito, rateio: 'Metade', valor: -50)];
      expect(debitoRowsForPerson(rows, Person.julio), hasLength(1));
      expect(debitoShareForPerson(rows, Person.julio), -25);
    });

    test('valor zero fica de fora (degenerado)', () {
      final rows = [_r(origem: kOrigemDebito, rateio: 'Metade', valor: 0)];
      expect(debitoRowsForPerson(rows, Person.julio), isEmpty);
    });
  });

  // A invariante voltou a valer em 2026-10-01, depois de alinhar a tela à fatia:
  // ambas são "Débito com rateio Metade". A tela abre a partir do número da
  // coluna Débito do Comparativo, então ela precisa somar exatamente aquele.
  group('reconciliação com a fatia Débito', () {
    final rows = [
      _r(origem: kOrigemCredito, rateio: 'Julio', valor: 500),
      _r(origem: kOrigemCredito, rateio: 'Metade', valor: 300),
      _r(origem: kOrigemDebito, rateio: 'Julio', valor: 120),
      _r(origem: kOrigemDebito, rateio: 'Metade', valor: 200),
      _r(origem: kOrigemDebito, rateio: 'Dani', valor: 70),
      _r(origem: kOrigemDebito, rateio: '', valor: 999),
      _r(origem: kOrigemDebito, rateio: 'Alzira', valor: 777),
    ];

    for (final person in Person.values) {
      test('soma da lista == fatia debito (${person.name})', () {
        expect(
          debitoShareForPerson(rows, person),
          closeTo(bucketsForPerson(rows, person).debito, 0.0001),
        );
      });
    }

    test('débito de rateio individual não entra na lista', () {
      // Ele soma em "Pessoal" e aparece na tela de Despesas pessoais.
      final lista = debitoRowsForPerson(rows, Person.julio);
      expect(lista, hasLength(1));
      expect(lista.single.rateio, 'Metade');
      expect(debitoShareForPerson(rows, Person.julio), 100); // 200/2
    });

    test('nada dividido no mês => lista vazia, e é o esperado', () {
      final soIndividual = [
        _r(origem: kOrigemDebito, rateio: 'Julio', valor: 120),
        _r(origem: kOrigemDebito, rateio: 'Dani', valor: 70),
      ];
      expect(debitoRowsForPerson(soIndividual, Person.julio), isEmpty);
      expect(bucketsForPerson(soIndividual, Person.julio).debito, 0);
    });
  });
}
