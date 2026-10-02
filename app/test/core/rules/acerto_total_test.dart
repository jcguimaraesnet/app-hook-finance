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

    test('categorias do crédito dividido somam o subtotal da linha', () {
      final comCategoria = [
        _r(origem: kOrigemCredito, rateio: kRateioCompartilhado, valor: 200, categoria: 'Casa'),
        _r(origem: kOrigemCredito, rateio: kRateioCompartilhado, valor: 60, categoria: 'Casa'),
        _r(origem: kOrigemCredito, rateio: kRateioCompartilhado, valor: 400, categoria: 'Mercado'),
        _r(origem: kOrigemCredito, rateio: 'Julio', valor: 90, categoria: 'Curso'),
        _r(origem: kOrigemDebito, rateio: kRateioCompartilhado, valor: 800, categoria: 'Casa'),
      ];
      for (final p in Person.values) {
        final cats = acertoCreditoCategorias(comCategoria, p, compartilhado: true);
        // Maior primeiro, uma entrada por categoria.
        expect(cats.map((c) => c.categoria), ['Mercado', 'Casa']);
        expect(cats.first.valor, 200); // 400/2
        expect(cats.last.valor, 130); // (200 + 60)/2
        expect(cats.fold<double>(0, (s, c) => s + c.valor),
            acertoBreakdown(comCategoria, p).creditoCompart,
            reason: 'categorias de ${p.name}');
      }
    });

    test('categoria vazia vira "—" e não some da lista', () {
      final cats = acertoCreditoCategorias([
        _r(origem: kOrigemCredito, rateio: kRateioCompartilhado, valor: 50, categoria: ''),
      ], Person.julio, compartilhado: true);
      expect(cats.single.categoria, '—');
      expect(cats.single.valor, 25);
    });

    // A linha "Crédito (pessoal)" abre pelo mesmo caminho, trocando o rateio.
    test('categorias do crédito pessoal somam o subtotal e usam valor cheio',
        () {
      final rows2 = [
        _r(origem: kOrigemCredito, rateio: 'Julio', valor: 90, categoria: 'Curso'),
        _r(origem: kOrigemCredito, rateio: 'Julio', valor: 30, categoria: 'Curso'),
        _r(origem: kOrigemCredito, rateio: 'Julio', valor: 200, categoria: 'Pessoal'),
        _r(origem: kOrigemCredito, rateio: 'Dani', valor: 500, categoria: 'Farmacia'),
        _r(origem: kOrigemCredito, rateio: kRateioCompartilhado, valor: 400, categoria: 'Curso'),
      ];
      final cats = acertoCreditoCategorias(rows2, Person.julio,
          compartilhado: false);
      expect(cats.map((c) => c.categoria), ['Pessoal', 'Curso']);
      expect(cats.first.valor, 200); // cheio, não metade
      expect(cats.last.valor, 120); // 90 + 30
      expect(cats.fold<double>(0, (s, c) => s + c.valor),
          acertoBreakdown(rows2, Person.julio).creditoPessoal);
      // Nada da outra pessoa nem do que é dividido.
      expect(cats.any((c) => c.categoria == 'Farmacia'), isFalse);
      expect(cats.fold<double>(0, (s, c) => s + c.valor), 320);
    });

    // A linha de subtotal que fecha as duas de crédito no card.
    test('subtotal de crédito é a soma das duas linhas', () {
      final b = acertoBreakdown(rows, Person.julio);
      expect(b.credito, b.creditoCompart + b.creditoPessoal);
      expect(b.credito, 180); // 100 + 80
      expect(b.credito + b.debitoCompart + b.debitoOutros + b.debitoPessoal,
          b.total);
    });

    test('mês vazio zera tudo', () {
      final b = acertoBreakdown(const [], Person.julio);
      expect(b.total, 0);
    });
  });
}
