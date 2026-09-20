import 'package:flutter_test/flutter_test.dart';
import 'package:hook_finance/core/rules/bucket_deltas.dart';
import 'package:hook_finance/core/origem.dart';
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
  group('bucketsForPerson', () {
    test('soma compart com metade do valor (Metade)', () {
      final rows = [
        _row(valor: 200, origem: kOrigemCredito, rateio: 'Metade'),
        _row(valor: 100, origem: kOrigemCredito, rateio: 'Metade'),
      ];
      final b = bucketsForPerson(rows, Person.julio);
      expect(b.compart, 150); // 100 + 50
      expect(b.pessoal, 0);
      expect(b.debito, 0);
    });

    test('soma pessoal apenas para a pessoa correspondente', () {
      final rows = [
        _row(valor: 80, origem: kOrigemCredito, rateio: 'Julio'),
        _row(valor: 50, origem: kOrigemCredito, rateio: 'Dani'),
      ];
      final ju = bucketsForPerson(rows, Person.julio);
      expect(ju.pessoal, 80);
      expect(ju.compart, 0);

      final da = bucketsForPerson(rows, Person.dani);
      expect(da.pessoal, 50);
      expect(da.compart, 0);
    });

    test('contas = origem != Cartão', () {
      final rows = [
        _row(valor: 30, origem: kOrigemDebito, rateio: 'Julio'),
        _row(valor: 40, origem: kOrigemDebito, rateio: 'Metade'),
      ];
      final b = bucketsForPerson(rows, Person.julio);
      expect(b.debito, 50); // 30 + 20
      expect(b.compart, 0);
      expect(b.pessoal, 0);
    });

    test('rows vazias → buckets zero', () {
      final b = bucketsForPerson(const [], Person.julio);
      expect(b.total, 0);
    });
  });

  group('bucketDeltas', () {
    test('delta% calculado quando previous > 0', () {
      final cur = const PersonBuckets(compart: 110, pessoal: 80, debito: 90);
      final prev = const PersonBuckets(compart: 100, pessoal: 100, debito: 0);
      final d = bucketDeltas(current: cur, previous: prev);
      expect(d.compart, 10.0);
      expect(d.pessoal, -20.0);
      expect(d.debito, isNull); // previous.debito == 0
    });

    test('previous tudo zero → todos os deltas null', () {
      final d = bucketDeltas(
        current: const PersonBuckets(compart: 50, pessoal: 0, debito: 10),
        previous: PersonBuckets.zero,
      );
      expect(d.compart, isNull);
      expect(d.pessoal, isNull);
      expect(d.debito, isNull);
    });

    test('current zero / previous cheio → -100%', () {
      final d = bucketDeltas(
        current: PersonBuckets.zero,
        previous: const PersonBuckets(compart: 50, pessoal: 50, debito: 50),
      );
      expect(d.compart, -100.0);
      expect(d.pessoal, -100.0);
      expect(d.debito, -100.0);
    });
  });

  group('previousMonthOf', () {
    test('MM/YYYY — mês comum', () {
      expect(previousMonthOf('06/2026'), '05/2026');
      expect(previousMonthOf('11/2025'), '10/2025');
    });

    test('MM/YYYY — janeiro vira dezembro do ano anterior', () {
      expect(previousMonthOf('01/2026'), '12/2025');
    });

    test('DD/MM/YYYY — preserva o dia', () {
      expect(previousMonthOf('06/06/2026'), '06/05/2026');
      expect(previousMonthOf('15/03/2026'), '15/02/2026');
    });

    test('DD/MM/YYYY — janeiro vira 12 do ano anterior, com dia', () {
      expect(previousMonthOf('06/01/2026'), '06/12/2025');
    });

    test('formato inválido → null', () {
      expect(previousMonthOf(null), isNull);
      expect(previousMonthOf(''), isNull);
      expect(previousMonthOf('2026-06'), isNull);
      expect(previousMonthOf('xx/yyyy'), isNull);
    });
  });
}
