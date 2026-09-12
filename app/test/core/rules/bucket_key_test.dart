import 'package:flutter_test/flutter_test.dart';
import 'package:hook_finance/core/rules/bucket_key.dart';
import 'package:hook_finance/core/types.dart';

ExpenseRow _row({String origem = 'Cartão', String rateio = ''}) => ExpenseRow(
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
    test('Cartão + Metade => Cartão (compartilhado)', () {
      expect(bucketKey(_row(origem: 'Cartão', rateio: 'Metade')),
          'Cartão (compartilhado)');
    });

    test('Cartão + Julio/Dani/Alzira => Cartão (pessoal)', () {
      expect(bucketKey(_row(origem: 'Cartão', rateio: 'Julio')),
          'Cartão (pessoal)');
      expect(bucketKey(_row(origem: 'Cartão', rateio: 'Dani')),
          'Cartão (pessoal)');
      expect(bucketKey(_row(origem: 'Cartão', rateio: 'Alzira')),
          'Cartão (pessoal)');
    });

    test('Cartão + rateio vazio => Cartão (pessoal)', () {
      expect(bucketKey(_row(origem: 'Cartão', rateio: '')),
          'Cartão (pessoal)');
    });

    test('Outras origens passam literal', () {
      expect(bucketKey(_row(origem: 'Pix (contas)', rateio: 'Julio')),
          'Pix (contas)');
      expect(bucketKey(_row(origem: 'Pessoal', rateio: '')), 'Pessoal');
      expect(bucketKey(_row(origem: 'Empregados', rateio: 'Metade')),
          'Empregados');
      expect(bucketKey(_row(origem: 'Contas', rateio: '')), 'Contas');
    });

    test('origem vazia retorna vazia', () {
      expect(bucketKey(_row(origem: '', rateio: 'Metade')), '');
    });
  });
}
