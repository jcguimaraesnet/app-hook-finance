import 'package:flutter_test/flutter_test.dart';
import 'package:hook_finance/api/client.dart';
import 'package:hook_finance/api/config.dart';
import 'package:hook_finance/api/endpoints.dart';
import 'package:hook_finance/core/origem.dart';
import 'package:hook_finance/core/types.dart';

/// Exercita a `faturaFoiCriada` de verdade, trocando só a ida à rede.
class _ApiComResposta extends ApiEndpoints {
  final MonthDataResponse resposta;
  final List<String?> mesesPedidos = [];

  _ApiComResposta(this.resposta)
      : super(ApiClient(const ApiConfig(token: 't')));

  @override
  Future<MonthDataResponse> getMonthData({String? month}) async {
    mesesPedidos.add(month);
    return resposta;
  }
}

Entry _e() => const Entry(
      row: 2,
      data: '06/12/2026',
      dataRef: '06/12/2026',
      descricao: 'Diarista',
      valor: 1600,
      origem: kOrigemDebito,
      categoria: 'Contas',
      rateio: 'Dani',
      banco: '',
      parcela: '',
      acerto: '',
    );

void main() {
  // Depois de um erro de rede em newInvoice, esta é a única prova de que a
  // fatura nasceu. Em 06/11/2026 ela não existia e a tela acusou falha numa
  // operação que tinha dado certo.
  group('faturaFoiCriada', () {
    test('mês com linhas => criada', () async {
      final api = _ApiComResposta(
        MonthDataResponse(ok: true, month: '06/12/2026', rows: [_e()]),
      );
      expect(await api.faturaFoiCriada('06/12/2026'), isTrue);
      expect(api.mesesPedidos, ['06/12/2026']);
    });

    test('mês vazio => não criada', () async {
      // monthData de mês inexistente responde ok com rows vazio.
      final api = _ApiComResposta(
        const MonthDataResponse(ok: true, month: '06/12/2026', rows: []),
      );
      expect(await api.faturaFoiCriada('06/12/2026'), isFalse);
    });

    test('resposta de erro não serve como prova', () async {
      final api = _ApiComResposta(
        const MonthDataResponse(ok: false, error: 'unauthorized'),
      );
      expect(await api.faturaFoiCriada('06/12/2026'), isFalse);
    });

    test('consulta exatamente o mês que tentou criar', () async {
      final api = _ApiComResposta(
        MonthDataResponse(ok: true, rows: [_e()]),
      );
      await api.faturaFoiCriada('06/01/2027');
      expect(api.mesesPedidos.single, '06/01/2027');
    });
  });
}
