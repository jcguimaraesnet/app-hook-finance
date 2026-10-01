import 'package:flutter_test/flutter_test.dart';
import 'package:hook_finance/core/origem.dart';
import 'package:hook_finance/core/rules/acerto_total.dart';
import 'package:hook_finance/core/types.dart';

ExpenseRow _r({
  required String origem,
  required String rateio,
  required double valor,
  String acerto = '',
  String descricao = 'x',
}) =>
    ExpenseRow(
      data: '06/11/2026',
      dataRef: '18/09/2026 10:00',
      descricao: descricao,
      valor: valor,
      origem: origem,
      categoria: 'Casa',
      rateio: rateio,
      banco: '',
      parcela: '',
      acerto: acerto,
    );

void main() {
  final rows = [
    _r(origem: kOrigemCredito, rateio: 'Metade', valor: 200, descricao: 'cred compart'),
    _r(origem: kOrigemCredito, rateio: 'Julio', valor: 80, descricao: 'cred julio'),
    _r(origem: kOrigemCredito, rateio: 'Dani', valor: 60, descricao: 'cred dani'),
    _r(origem: kOrigemDebito, rateio: 'Metade', valor: 400, acerto: 'Sim', descricao: 'deb compart'),
    _r(origem: kOrigemDebito, rateio: 'Julio', valor: 100, acerto: 'Sim', descricao: 'deb julio marcado'),
    _r(origem: kOrigemDebito, rateio: 'Julio', valor: 30, descricao: 'deb julio sem marca'),
    _r(origem: kOrigemDebito, rateio: 'Dani', valor: 70, descricao: 'deb dani sem marca'),
    _r(origem: kOrigemDebito, rateio: 'Alzira', valor: 999, descricao: 'de terceiro'),
  ];

  group('acertoBreakdown', () {
    test('as quatro linhas, pela regra de cada uma', () {
      final b = acertoBreakdown(rows, Person.julio);
      expect(b.creditoCompart, 100); // 200/2
      expect(b.creditoPessoal, 80);
      expect(b.debitoCompart, 200); // 400/2
      expect(b.debitoPessoal, 130); // 100 + 30, valor cheio
      expect(b.total, 510);
    });

    // O pedido do usuário em 2026-10-01: o card mostrava só a Diarista entre os
    // cinco débitos da Dani, porque a coluna Acerto filtrava.
    test('débito sem acerto=Sim também entra', () {
      final b = acertoBreakdown(rows, Person.dani);
      expect(b.debitoPessoal, 70);
      final linhas = acertoDebitoRows(rows, Person.dani);
      expect(linhas.pessoal.map((r) => r.descricao), ['deb dani sem marca']);
    });

    test('débito de terceiro não entra em nenhuma das duas', () {
      final l = acertoDebitoRows(rows, Person.julio);
      expect(l.compart.map((r) => r.descricao), ['deb compart']);
      expect(l.pessoal.map((r) => r.descricao),
          ['deb julio marcado', 'deb julio sem marca']);
    });

    test('as listas somam exatamente os subtotais do card', () {
      for (final p in Person.values) {
        final b = acertoBreakdown(rows, p);
        final l = acertoDebitoRows(rows, p);
        expect(l.pessoal.fold<double>(0, (s, r) => s + r.valor), b.debitoPessoal,
            reason: 'pessoal de ${p.name}');
      }
    });

    test('mês vazio zera tudo', () {
      final b = acertoBreakdown(const [], Person.julio);
      expect(b.total, 0);
    });
  });
}
