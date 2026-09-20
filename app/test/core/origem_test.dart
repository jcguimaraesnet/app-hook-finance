import 'package:flutter_test/flutter_test.dart';
import 'package:hook_finance/core/origem.dart';
import 'package:hook_finance/core/types.dart';

void main() {
  group('normalizeOrigem', () {
    test('mapeia o enum antigo', () {
      expect(normalizeOrigem('Cartão'), kOrigemCredito);
      expect(normalizeOrigem('Pix (contas)'), kOrigemDebito);
      expect(normalizeOrigem('Contas'), kOrigemDebito);
      expect(normalizeOrigem('Empregados'), kOrigemDebito);
      expect(normalizeOrigem('Pessoal'), kOrigemDebito);
    });

    test('valor novo passa intacto (idempotente)', () {
      expect(normalizeOrigem(kOrigemCredito), kOrigemCredito);
      expect(normalizeOrigem(kOrigemDebito), kOrigemDebito);
      expect(normalizeOrigem(normalizeOrigem('Cartão')), kOrigemCredito);
    });

    test('desconhecido passa intacto, para aparecer na UI', () {
      expect(normalizeOrigem('Boleto'), 'Boleto');
    });

    test('vazio e espaços', () {
      expect(normalizeOrigem(''), '');
      expect(normalizeOrigem('   '), '');
      expect(normalizeOrigem(' Cartão '), kOrigemCredito);
    });
  });

  // A ponte precisa agir na desserialização: entre publicar o app e rodar a
  // migração, a planilha ainda devolve o enum antigo e toda tela filtra pelo
  // novo. Sem isso o app mostraria zero em tudo nesse intervalo.
  group('normalização na leitura', () {
    Map<String, dynamic> json(String origem) => {
          'row': 7,
          'data': '06/10/2026',
          'dataRef': '18/09/2026 10:00',
          'descricao': 'MERCADO',
          'valor': 10.0,
          'origem': origem,
          'categoria': 'Casa',
          'rateio': 'Julio',
          'banco': '',
          'parcela': '',
          'acerto': '',
        };

    test('ExpenseRow.fromJson normaliza', () {
      expect(ExpenseRow.fromJson(json('Cartão')).origem, kOrigemCredito);
      expect(ExpenseRow.fromJson(json('Pix (contas)')).origem, kOrigemDebito);
    });

    test('Entry.fromJson normaliza e mantém o row', () {
      final e = Entry.fromJson(json('Empregados'));
      expect(e.origem, kOrigemDebito);
      expect(e.row, 7);
    });

    test('monthData com dado ainda não migrado já chega normalizado', () {
      final r = MonthDataResponse.fromJson({
        'ok': true,
        'rows': [json('Cartão'), json('Contas')],
      });
      expect(r.rows.map((e) => e.origem), [kOrigemCredito, kOrigemDebito]);
    });
  });
}
