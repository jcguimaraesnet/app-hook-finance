import 'package:flutter_test/flutter_test.dart';
import 'package:hook_finance/core/rules/split_for_person.dart';
import 'package:hook_finance/core/types.dart';

ExpenseRow _row({
  double valor = 100,
  String origem = 'Cartão',
  String rateio = '',
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
      acerto: '',
    );

void main() {
  group('splitForPerson', () {
    test('retorna valor cheio quando rateio === person', () {
      expect(splitForPerson(_row(valor: 80, rateio: 'Julio'), Person.julio),
          80);
      expect(
          splitForPerson(_row(valor: 50, rateio: 'Dani'), Person.dani), 50);
    });

    test("retorna valor/2 quando rateio === 'Metade' (Julio/Dani)", () {
      expect(
          splitForPerson(_row(valor: 100, rateio: 'Metade'), Person.julio),
          50);
      expect(
          splitForPerson(_row(valor: 100, rateio: 'Metade'), Person.dani), 50);
    });

    test('retorna 0 quando rateio é de outra pessoa', () {
      expect(splitForPerson(_row(valor: 80, rateio: 'Dani'), Person.julio), 0);
      expect(splitForPerson(_row(valor: 80, rateio: 'Julio'), Person.dani), 0);
      expect(splitForPerson(_row(valor: 80, rateio: 'Alzira'), Person.julio),
          0);
    });

    test('retorna 0 quando rateio é vazio', () {
      expect(splitForPerson(_row(valor: 80, rateio: ''), Person.julio), 0);
    });

    test('preserva sinal do valor (negativo => negativo)', () {
      expect(splitForPerson(_row(valor: -100, rateio: 'Julio'), Person.julio),
          -100);
      expect(splitForPerson(_row(valor: -100, rateio: 'Metade'), Person.dani),
          -50);
    });

    test('retorna 0 para valor zero independente do rateio', () {
      expect(splitForPerson(_row(valor: 0, rateio: 'Julio'), Person.julio), 0);
      expect(splitForPerson(_row(valor: 0, rateio: 'Metade'), Person.julio),
          0);
    });
  });
}
