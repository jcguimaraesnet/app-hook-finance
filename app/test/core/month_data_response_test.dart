import 'package:flutter_test/flutter_test.dart';
import 'package:hook_finance/core/types.dart';

Map<String, dynamic> _row({
  Object? row = 137,
  String data = '06/10/2026',
  String descricao = 'MERCADO ABC',
}) {
  final j = <String, dynamic>{
    'data': data,
    'dataRef': '03/09/2026 14:32',
    'descricao': descricao,
    'valor': 89.5,
    'origem': 'Cartão',
    'categoria': 'Alimentação',
    'rateio': 'Julio',
    'banco': 'Santander',
    'parcela': '',
    'acerto': '',
  };
  if (row != null) j['row'] = row;
  return j;
}

void main() {
  group('MonthDataResponse.fromJson', () {
    test('preserva o row da planilha (edição direto do detalhe)', () {
      final r = MonthDataResponse.fromJson({
        'ok': true,
        'month': '06/10/2026',
        'rows': [_row(row: 137)],
      });
      expect(r.rows.single.row, 137);
      expect(r.rows.single.descricao, 'MERCADO ABC');
    });

    test('row ausente (backend antigo) cai em 0 = não-editável', () {
      final r = MonthDataResponse.fromJson({
        'ok': true,
        'rows': [_row(row: null)],
      });
      expect(r.rows.single.row, 0);
      expect(r.rows.single.row >= 2, isFalse);
    });

    test('rows vazias do bloco de fatura saem da lista sem deslocar row', () {
      final r = MonthDataResponse.fromJson({
        'ok': true,
        'rows': [
          _row(row: 10, data: '', descricao: '   '),
          _row(row: 11),
        ],
      });
      expect(r.rows.length, 1);
      expect(r.rows.single.row, 11);
    });

    test('rows ausente/nula retorna lista vazia', () {
      expect(MonthDataResponse.fromJson({'ok': true}).rows, isEmpty);
    });
  });
}
