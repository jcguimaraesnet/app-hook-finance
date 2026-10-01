import 'package:flutter_test/flutter_test.dart';
import 'package:hook_finance/core/rules/bucket_deltas.dart';
import 'package:hook_finance/core/origem.dart';
import 'package:hook_finance/core/rules/debito_rows.dart';
import 'package:hook_finance/core/rules/split_for_person.dart';
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

  // ATENÇÃO — a invariante mudou em 2026-10-01.
  //
  // Até então, a soma desta lista era exatamente o bucket `debito` do card
  // Comparativo. A nova regra das fatias (ver bucket-deltas.md) manda o Débito
  // com rateio individual para `pessoal`, e deixa em `debito` apenas o que tem
  // rateio Metade. Esta lista continua sendo "todo o débito que toca a pessoa",
  // porque é isso que a tela de Débito serve para mostrar.
  //
  // Resultado: a coluna Débito do Comparativo NÃO soma mais o que esta tela
  // lista. Divergência conhecida e pendente de decisão do usuário — fixada aqui
  // para não passar por acidente.
  group('relação com as fatias do Comparativo', () {
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
      test('bucket debito = só o Débito com Metade (${person.name})', () {
        final metadeSo = rows
            .where((r) => r.origem == kOrigemDebito && r.rateio == 'Metade')
            .fold<double>(0, (s, r) => s + splitForPerson(r, person));
        expect(bucketsForPerson(rows, person).debito, metadeSo);
      });

      test('lista da tela = bucket debito + o Débito individual da pessoa '
          '(${person.name})', () {
        final b = bucketsForPerson(rows, person);
        final debitoIndividual = rows
            .where((r) => r.origem == kOrigemDebito && r.rateio == person.name)
            .fold<double>(0, (s, r) => s + splitForPerson(r, person));
        expect(
          debitoShareForPerson(rows, person),
          closeTo(b.debito + debitoIndividual, 0.0001),
        );
      });
    }

    test('linhas ignoradas pelas fatias também somem da lista', () {
      final descricoes =
          debitoRowsForPerson(rows, Person.julio).map((r) => r.descricao);
      expect(descricoes, everyElement('x'));
      // 120 (Julio) + 200/2 (Metade) = 220
      expect(debitoShareForPerson(rows, Person.julio), 220);
    });
  });
}
