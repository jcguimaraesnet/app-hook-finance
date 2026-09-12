import 'package:flutter_test/flutter_test.dart';
import 'package:hook_finance/core/rules/diff_calculation.dart';
import 'package:hook_finance/core/types.dart';

ExpenseRow _row({
  double valor = 0,
  String origem = 'Cartão',
  String rateio = '',
  String acerto = '',
}) =>
    ExpenseRow(
      data: '06/05/2026',
      dataRef: '03/04/2026 14:32',
      descricao: 'TEST',
      valor: valor,
      origem: origem,
      categoria: '',
      rateio: rateio,
      banco: '',
      parcela: '',
      acerto: acerto,
    );

void main() {
  group('diffCalculation', () {
    group('quando o mês tem Pix', () {
      test('considera todas as Pix (não filtra por acerto)', () {
        final rows = [
          _row(
              origem: 'Pix (contas)',
              rateio: 'Julio',
              valor: 1000,
              acerto: 'Sim'),
          _row(origem: 'Pix (contas)', rateio: 'Dani', valor: 700),
        ];
        expect(diffCalculation(rows, Person.julio), 300);
        expect(diffCalculation(rows, Person.dani), -300);
      });

      test('ignora Cartão e Contas/Empregados quando há Pix', () {
        final rows = [
          _row(origem: 'Pix (contas)', rateio: 'Julio', valor: 500),
          _row(origem: 'Cartão', rateio: 'Metade', valor: 200),
          _row(origem: 'Contas', rateio: 'Dani', valor: 100),
        ];
        expect(diffCalculation(rows, Person.julio), 500);
        expect(diffCalculation(rows, Person.dani), -500);
      });

      test('aplica splitForPerson em Pix com rateio Metade', () {
        final rows = [
          _row(origem: 'Pix (contas)', rateio: 'Metade', valor: 200),
        ];
        expect(diffCalculation(rows, Person.julio), 0);
      });
    });

    group('quando o mês NÃO tem Pix', () {
      test('considera Contas + Empregados', () {
        final rows = [
          _row(origem: 'Contas', rateio: 'Julio', valor: 300),
          _row(origem: 'Empregados', rateio: 'Dani', valor: 150),
        ];
        expect(diffCalculation(rows, Person.julio), 150);
        expect(diffCalculation(rows, Person.dani), -150);
      });

      test('ignora Cartão e outras origens', () {
        final rows = [
          _row(origem: 'Cartão', rateio: 'Julio', valor: 1000),
          _row(origem: 'Pessoal', rateio: 'Julio', valor: 500),
          _row(origem: 'Contas', rateio: 'Julio', valor: 100),
        ];
        expect(diffCalculation(rows, Person.julio), 100);
      });
    });

    test('mês completamente vazio retorna 0', () {
      expect(diffCalculation([], Person.julio), 0);
      expect(diffCalculation([], Person.dani), 0);
    });

    test('preserva sinal do valor (negativos)', () {
      final rows = [
        _row(origem: 'Pix (contas)', rateio: 'Julio', valor: -100),
      ];
      expect(diffCalculation(rows, Person.julio), -100);
      expect(diffCalculation(rows, Person.dani), 100);
    });
  });
}
