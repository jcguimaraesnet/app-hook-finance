import 'package:flutter_test/flutter_test.dart';
import 'package:hook_finance/core/rules/bucket_key.dart';
import 'package:hook_finance/core/origem.dart';
import 'package:hook_finance/core/types.dart';

ExpenseRow _row({String origem = kOrigemCredito, String rateio = ''}) => ExpenseRow(
      data: '06/05/2026',
      dataRef: '03/04/2026 14:32',
      descricao: 'TEST',
      valor: 100,
      origem: origem,
      categoria: '',
      rateio: rateio,
      banco: '',
      parcela: '',
      acerto: '',
    );

void main() {
  group('bucketKey', () {
    test('Crédito + Metade => Crédito (compartilhado)', () {
      expect(bucketKey(_row(origem: kOrigemCredito, rateio: 'Metade')),
          'Crédito (compartilhado)');
    });

    test('Crédito + Julio/Dani/Alzira => Crédito (pessoal)', () {
      expect(bucketKey(_row(origem: kOrigemCredito, rateio: 'Julio')),
          'Crédito (pessoal)');
      expect(bucketKey(_row(origem: kOrigemCredito, rateio: 'Dani')),
          'Crédito (pessoal)');
      expect(bucketKey(_row(origem: kOrigemCredito, rateio: 'Alzira')),
          'Crédito (pessoal)');
    });

    test('Crédito + rateio vazio => Crédito (pessoal)', () {
      expect(bucketKey(_row(origem: kOrigemCredito, rateio: '')),
          'Crédito (pessoal)');
    });

    test('Débito passa literal, seja qual for o rateio', () {
      for (final rateio in ['Julio', 'Dani', 'Metade', 'Alzira', '']) {
        expect(bucketKey(_row(origem: kOrigemDebito, rateio: rateio)),
            kOrigemDebito);
      }
    });

    test('origem legada não migrada passa literal em vez de sumir', () {
      // A regra não normaliza: quem normaliza é a leitura (core/origem.dart).
      // Se uma linha escapar da migração, o bucket aparece com o nome velho na
      // UI — visível — em vez de ser silenciosamente contado como Débito.
      expect(bucketKey(_row(origem: 'Pix (contas)', rateio: 'Julio')),
          'Pix (contas)');
    });

    test('origem vazia retorna vazia', () {
      expect(bucketKey(_row(origem: '', rateio: 'Metade')), '');
    });
  });
}
