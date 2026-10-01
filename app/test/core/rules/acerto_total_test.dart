import 'package:flutter_test/flutter_test.dart';
import 'package:hook_finance/core/origem.dart';
import 'package:hook_finance/core/rules/acerto_total.dart';
import 'package:hook_finance/core/rateio.dart';
import 'package:hook_finance/core/types.dart';

ExpenseRow _r({
  required String origem,
  required String rateio,
  required double valor,
  String acerto = '',
  String descricao = 'x',
  String categoria = 'Casa',
}) =>
    ExpenseRow(
      data: '06/11/2026',
      dataRef: '18/09/2026 10:00',
      descricao: descricao,
      valor: valor,
      origem: origem,
      categoria: categoria,
      rateio: rateio,
      banco: '',
      parcela: '',
      acerto: acerto,
    );

void main() {
  final rows = [
    _r(origem: kOrigemCredito, rateio: kRateioCompartilhado, valor: 200, descricao: 'cred compart'),
    _r(origem: kOrigemCredito, rateio: 'Julio', valor: 80, descricao: 'cred julio'),
    _r(origem: kOrigemCredito, rateio: 'Dani', valor: 60, descricao: 'cred dani'),
    _r(origem: kOrigemDebito, rateio: kRateioCompartilhado, valor: 400, acerto: 'Sim', descricao: 'deb compart'),
    _r(origem: kOrigemDebito, rateio: 'Julio', valor: 100, acerto: 'Sim', descricao: 'deb julio marcado'),
    _r(origem: kOrigemDebito, rateio: 'Julio', valor: 30, descricao: 'deb julio sem marca'),
    _r(origem: kOrigemDebito, rateio: 'Julio', valor: 25, categoria: 'Pessoal', descricao: 'deb julio pessoal'),
    _r(origem: kOrigemDebito, rateio: 'Dani', valor: 70, descricao: 'deb dani sem marca'),
    _r(origem: kOrigemDebito, rateio: 'Alzira', valor: 999, descricao: 'de terceiro'),
  ];

  group('acertoBreakdown', () {
    test('as cinco linhas, pela regra de cada uma', () {
      final b = acertoBreakdown(rows, Person.julio);
      expect(b.creditoCompart, 100); // 200/2
      expect(b.creditoPessoal, 80);
      expect(b.debitoCompart, 200); // 400/2
      expect(b.debitoOutros, 130); // 100 + 30, valor cheio
      expect(b.debitoPessoal, 25); // só a categoria Pessoal
      expect(b.total, 535);
    });

    // O pedido do usuário em 2026-10-01: o card mostrava só a Diarista entre os
    // cinco débitos da Dani, porque a coluna Acerto filtrava.
    test('débito sem acerto=Sim também entra', () {
      final b = acertoBreakdown(rows, Person.dani);
      expect(b.debitoOutros, 70);
      final linhas = acertoDebitoRows(rows, Person.dani);
      expect(linhas.outros.map((r) => r.descricao), ['deb dani sem marca']);
    });

    test('débito de terceiro não entra em nenhum dos três grupos', () {
      final l = acertoDebitoRows(rows, Person.julio);
      expect(l.compart.map((r) => r.descricao), ['deb compart']);
      expect(l.outros.map((r) => r.descricao),
          ['deb julio marcado', 'deb julio sem marca']);
      expect(l.pessoal.map((r) => r.descricao), ['deb julio pessoal']);
    });

    test('a categoria separa outros de pessoal, sem perder linha', () {
      final l = acertoDebitoRows(rows, Person.julio);
      expect(l.outros.any((r) => r.categoria == 'Pessoal'), isFalse);
      expect(l.pessoal.every((r) => r.categoria == 'Pessoal'), isTrue);
      expect(l.outros.length + l.pessoal.length,
          rows.where((r) => r.origem == kOrigemDebito && r.rateio == 'Julio').length);
    });

    test('categoria com caixa/espaço diferentes ainda é pessoal', () {
      final l = acertoDebitoRows([
        _r(origem: kOrigemDebito, rateio: 'Julio', valor: 10, categoria: ' pessoal '),
      ], Person.julio);
      expect(l.pessoal, hasLength(1));
      expect(l.outros, isEmpty);
    });

    test('as listas somam exatamente os subtotais do card', () {
      for (final p in Person.values) {
        final b = acertoBreakdown(rows, p);
        final l = acertoDebitoRows(rows, p);
        expect(l.outros.fold<double>(0, (s, r) => s + r.valor), b.debitoOutros,
            reason: 'outros de ${p.name}');
        expect(l.pessoal.fold<double>(0, (s, r) => s + r.valor), b.debitoPessoal,
            reason: 'pessoal de ${p.name}');
      }
    });

    // A divisão em dois grupos é só de apresentação: o que a pessoa transfere
    // não pode mudar por causa dela.
    test('separar outros de pessoal não muda o total', () {
      for (final p in Person.values) {
        final b = acertoBreakdown(rows, p);
        final debitoDaPessoa = rows
            .where((r) => r.origem == kOrigemDebito && r.rateio == p.name)
            .fold<double>(0, (s, r) => s + r.valor);
        expect(b.debitoOutros + b.debitoPessoal, debitoDaPessoa,
            reason: 'débito da ${p.name}');
      }
    });

    test('mês vazio zera tudo', () {
      final b = acertoBreakdown(const [], Person.julio);
      expect(b.total, 0);
    });
  });
}
