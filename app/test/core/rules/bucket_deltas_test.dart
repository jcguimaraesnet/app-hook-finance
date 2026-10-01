import 'package:flutter_test/flutter_test.dart';
import 'package:hook_finance/core/rules/bucket_deltas.dart';
import 'package:hook_finance/core/origem.dart';
import 'package:hook_finance/core/rateio.dart';
import 'package:hook_finance/core/types.dart';

ExpenseRow _row({
  required double valor,
  String origem = kOrigemCredito,
  String rateio = '',
}) =>
    ExpenseRow(
      data: '01/06/2026',
      dataRef: '01/06/2026 12:00',
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
  // Pós-2026-10-01 o corte é por rateio primeiro, origem depois:
  //   pessoal = rateio da pessoa, em qualquer origem
  //   credito = Crédito + Metade
  //   debito  = Débito + Metade
  group('bucketsForPerson', () {
    test('credito = Crédito com Metade, pela metade do valor', () {
      final rows = [
        _row(valor: 200, origem: kOrigemCredito, rateio: kRateioCompartilhado),
        _row(valor: 100, origem: kOrigemCredito, rateio: kRateioCompartilhado),
      ];
      final b = bucketsForPerson(rows, Person.julio);
      expect(b.credito, 150); // 100 + 50
      expect(b.pessoal, 0);
      expect(b.debito, 0);
    });

    test('debito = Débito com Metade, pela metade do valor', () {
      final rows = [_row(valor: 40, origem: kOrigemDebito, rateio: kRateioCompartilhado)];
      final b = bucketsForPerson(rows, Person.julio);
      expect(b.debito, 20);
      expect(b.credito, 0);
      expect(b.pessoal, 0);
    });

    test('pessoal junta Crédito E Débito do rateio da pessoa', () {
      final rows = [
        _row(valor: 80, origem: kOrigemCredito, rateio: 'Julio'),
        _row(valor: 30, origem: kOrigemDebito, rateio: 'Julio'),
        _row(valor: 50, origem: kOrigemCredito, rateio: 'Dani'),
        _row(valor: 70, origem: kOrigemDebito, rateio: 'Dani'),
      ];
      final ju = bucketsForPerson(rows, Person.julio);
      expect(ju.pessoal, 110); // 80 + 30, valor cheio
      expect(ju.credito, 0);
      expect(ju.debito, 0);

      final da = bucketsForPerson(rows, Person.dani);
      expect(da.pessoal, 120); // 50 + 70
    });

    // O que mudou: antes, Débito com rateio individual caía na fatia de débito.
    // Era o caso de 100% das linhas de Débito da planilha, então a fatia Débito
    // zerou e Pessoal absorveu tudo — medido na fatura 06/11/2026.
    test('Débito com rateio individual vai para pessoal, não para debito', () {
      final rows = [_row(valor: 30, origem: kOrigemDebito, rateio: 'Julio')];
      final b = bucketsForPerson(rows, Person.julio);
      expect(b.pessoal, 30);
      expect(b.debito, 0);
    });

    test('rateio de terceiro não entra em nenhuma fatia', () {
      final rows = [
        _row(valor: 90, origem: kOrigemCredito, rateio: 'Alzira'),
        _row(valor: 90, origem: kOrigemDebito, rateio: ''),
      ];
      final b = bucketsForPerson(rows, Person.julio);
      expect(b.total, 0);
    });

    test('as três fatias continuam particionando o total', () {
      final rows = [
        _row(valor: 200, origem: kOrigemCredito, rateio: kRateioCompartilhado),
        _row(valor: 100, origem: kOrigemDebito, rateio: kRateioCompartilhado),
        _row(valor: 80, origem: kOrigemCredito, rateio: 'Julio'),
        _row(valor: 30, origem: kOrigemDebito, rateio: 'Julio'),
        _row(valor: 999, origem: kOrigemCredito, rateio: 'Dani'),
      ];
      final b = bucketsForPerson(rows, Person.julio);
      expect(b.credito, 100);
      expect(b.debito, 50);
      expect(b.pessoal, 110);
      expect(b.total, 260);
    });

    // Os dois agrupamentos da Início desde 2026-10-01.
    test('compartilhado = crédito + débito, e com pessoal fecha o total', () {
      final rows = [
        _row(valor: 200, origem: kOrigemCredito, rateio: kRateioCompartilhado),
        _row(valor: 100, origem: kOrigemDebito, rateio: kRateioCompartilhado),
        _row(valor: 80, origem: kOrigemCredito, rateio: 'Julio'),
      ];
      final b = bucketsForPerson(rows, Person.julio);
      expect(b.compartilhado, 150); // 100 + 50
      expect(b.compartilhado + b.pessoal, b.total);
    });

    // O card de totais da Início mostra os quatro em 2×2; se não particionassem
    // o total, a soma dos tiles não bateria com o número grande acima deles.
    test('os quatro quadrantes particionam o total', () {
      final rows = [
        _row(valor: 200, origem: kOrigemCredito, rateio: kRateioCompartilhado),
        _row(valor: 100, origem: kOrigemDebito, rateio: kRateioCompartilhado),
        _row(valor: 80, origem: kOrigemCredito, rateio: 'Julio'),
        _row(valor: 30, origem: kOrigemDebito, rateio: 'Julio'),
        _row(valor: 999, origem: kOrigemDebito, rateio: 'Alzira'),
      ];
      final b = bucketsForPerson(rows, Person.julio);
      expect(b.credito, 100); // 200/2
      expect(b.debito, 50); // 100/2
      expect(b.pessoalCredito, 80);
      expect(b.pessoalDebito, 30);
      expect(b.credito + b.debito + b.pessoalCredito + b.pessoalDebito,
          b.total);
      expect(b.total, 260);
    });

    test('rows vazias → buckets zero', () {
      final b = bucketsForPerson(const [], Person.julio);
      expect(b.total, 0);
      expect(b.compartilhado, 0);
      expect(b.pessoalCredito, 0);
      expect(b.pessoalDebito, 0);
    });
  });
}
