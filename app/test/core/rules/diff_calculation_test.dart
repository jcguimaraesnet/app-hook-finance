import 'package:flutter_test/flutter_test.dart';
import 'package:hook_finance/core/origem.dart';
import 'package:hook_finance/core/rules/diff_calculation.dart';
import 'package:hook_finance/core/rateio.dart';
import 'package:hook_finance/core/types.dart';

ExpenseRow _row({
  double valor = 0,
  String origem = kOrigemCredito,
  String rateio = '',
  String acerto = '',
  String categoria = 'Casa',
}) =>
    ExpenseRow(
      data: '06/05/2026',
      dataRef: '03/04/2026 14:32',
      descricao: 'TEST',
      valor: valor,
      origem: origem,
      categoria: categoria,
      rateio: rateio,
      banco: '',
      parcela: '',
      acerto: acerto,
    );

void main() {
  group('diffCalculation', () {
    test('soma Débito (outros) das duas pessoas e devolve a diferença', () {
      final rows = [
        _row(origem: kOrigemDebito, rateio: 'Julio', valor: 500),
        _row(origem: kOrigemDebito, rateio: 'Dani', valor: 100),
      ];
      expect(diffCalculation(rows, Person.julio), 400);
      expect(diffCalculation(rows, Person.dani), -400);
    });

    test('não filtra por acerto', () {
      final rows = [
        _row(origem: kOrigemDebito, rateio: 'Julio', valor: 300, acerto: 'Sim'),
        _row(origem: kOrigemDebito, rateio: 'Julio', valor: 200),
      ];
      expect(diffCalculation(rows, Person.julio), 500);
    });

    test('ignora Crédito', () {
      final rows = [
        _row(origem: kOrigemCredito, rateio: 'Julio', valor: 900),
        _row(origem: kOrigemDebito, rateio: 'Julio', valor: 100),
      ];
      expect(diffCalculation(rows, Person.julio), 100);
    });

    test('Compartilhado não entra (já é metade de cada um)', () {
      final rows = [_row(origem: kOrigemDebito, rateio: kRateioCompartilhado, valor: 400)];
      expect(diffCalculation(rows, Person.julio), 0);
      expect(diffCalculation(rows, Person.dani), 0);
    });

    // O pedido de 2026-10-01: o pill passou a ser a diferença entre as duas
    // linhas "Débito (outros)" da tela, então a categoria Pessoal fica fora.
    test('categoria Pessoal não entra', () {
      final rows = [
        _row(origem: kOrigemDebito, rateio: 'Julio', valor: 500),
        _row(origem: kOrigemDebito, rateio: 'Julio', valor: 900, categoria: 'Pessoal'),
        _row(origem: kOrigemDebito, rateio: 'Dani', valor: 100),
        _row(origem: kOrigemDebito, rateio: 'Dani', valor: 400, categoria: 'Pessoal'),
      ];
      expect(diffCalculation(rows, Person.julio), 400); // 500 - 100
    });

    // A tela mostra o mesmo pill nos dois cards; o sinal é que muda.
    test('é simétrico entre as duas pessoas', () {
      final rows = [
        _row(origem: kOrigemDebito, rateio: 'Julio', valor: 1944.42),
        _row(origem: kOrigemDebito, rateio: 'Dani', valor: 2100),
      ];
      expect(diffCalculation(rows, Person.julio),
          -diffCalculation(rows, Person.dani));
      expect(diffCalculation(rows, Person.julio).abs(), closeTo(155.58, 0.001));
    });

    test('rateio que não toca ninguém não entra', () {
      final rows = [
        _row(origem: kOrigemDebito, rateio: 'Alzira', valor: 700),
        _row(origem: kOrigemDebito, rateio: '', valor: 800),
      ];
      expect(diffCalculation(rows, Person.julio), 0);
    });

    test('mês vazio retorna 0', () {
      expect(diffCalculation(const <ExpenseRow>[], Person.julio), 0);
    });

    test('preserva sinal do valor (estorno)', () {
      final rows = [_row(origem: kOrigemDebito, rateio: 'Julio', valor: -150)];
      expect(diffCalculation(rows, Person.julio), -150);
    });

    // Pix e Contas/Empregados agora são o mesmo valor. Antes da migração a regra
    // escolhia um conjunto ou outro; como os dois nunca coexistiam num mês, somar
    // tudo dá o mesmo número — conferido nos 12 meses da planilha.
    test('linhas das duas eras somam juntas, sem ramo', () {
      final rows = [
        _row(origem: kOrigemDebito, rateio: 'Julio', valor: 100), // era Pix
        _row(origem: kOrigemDebito, rateio: 'Julio', valor: 50), // era Contas
        _row(origem: kOrigemDebito, rateio: 'Dani', valor: 30), // era Empregados
      ];
      expect(diffCalculation(rows, Person.julio), 120);
    });
  });
}
