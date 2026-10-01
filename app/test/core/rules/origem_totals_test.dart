import 'package:flutter_test/flutter_test.dart';
import 'package:hook_finance/core/origem.dart';
import 'package:hook_finance/core/rateio.dart';
import 'package:hook_finance/core/rules/bucket_deltas.dart';
import 'package:hook_finance/core/rules/origem_totals.dart';
import 'package:hook_finance/core/types.dart';

ExpenseRow _r({
  required String origem,
  required String rateio,
  required double valor,
}) =>
    ExpenseRow(
      data: '06/11/2026',
      dataRef: '18/09/2026 10:00',
      descricao: 'x',
      valor: valor,
      origem: origem,
      categoria: 'Casa',
      rateio: rateio,
      banco: '',
      parcela: '',
      acerto: '',
    );

void main() {
  final rows = [
    _r(origem: kOrigemCredito, rateio: kRateioCompartilhado, valor: 200),
    _r(origem: kOrigemCredito, rateio: 'Julio', valor: 80),
    _r(origem: kOrigemCredito, rateio: 'Dani', valor: 60),
    _r(origem: kOrigemDebito, rateio: kRateioCompartilhado, valor: 400),
    _r(origem: kOrigemDebito, rateio: 'Julio', valor: 100),
    _r(origem: kOrigemDebito, rateio: 'Alzira', valor: 999),
    _r(origem: kOrigemDebito, rateio: '', valor: 777),
  ];

  group('origemTotals', () {
    test('soma as duas pessoas por origem', () {
      final t = origemTotals(rows);
      expect(t.credito, 340); // 200 (100+100) + 80 + 60
      expect(t.debito, 500); // 400 (200+200) + 100
    });

    test('linha de terceiro e linha sem rateio ficam de fora', () {
      final t = origemTotals(rows);
      expect(t.total, 840);
      expect(t.total, lessThan(rows.fold<double>(0, (s, r) => s + r.valor)));
    });

    // O par de tiles fica logo abaixo dos tiles de pessoa; somar os dois tem
    // que dar o mesmo que somar aqueles, senão a tela se contradiz.
    test('crédito + débito = total do Júlio + total da Dani', () {
      final t = origemTotals(rows);
      final porPessoa = bucketsForPerson(rows, Person.julio).total +
          bucketsForPerson(rows, Person.dani).total;
      expect(t.total, porPessoa);
    });

    test('mês vazio zera', () {
      expect(origemTotals(const []).total, 0);
    });
  });
}
