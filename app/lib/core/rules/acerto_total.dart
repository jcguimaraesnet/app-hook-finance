// Spec: docs/specs/cards/acerto-card.md
// Mudanças aqui DEVEM começar pela spec.

import '../rateio.dart';
import '../origem.dart';
import '../types.dart';
import 'split_for_person.dart';

/// As cinco linhas do card de Acerto e o total da pessoa.
///
/// Existe porque o número grande do topo ("X TRANSFERE PARA Y") e o "Total
/// Pessoal" do card são o mesmo valor e estavam calculados em dois lugares. Em
/// 2026-10-01 a linha de débito compartilhado entrou no card e a cópia do topo
/// não acompanhou: a tela passou a mostrar R$ 4.566,65 em cima e R$ 7.883,06
/// embaixo.
class AcertoBreakdown {
  final double creditoCompart;
  final double creditoPessoal;
  final double debitoCompart;
  final double debitoOutros;
  final double debitoPessoal;

  const AcertoBreakdown({
    required this.creditoCompart,
    required this.creditoPessoal,
    required this.debitoCompart,
    required this.debitoOutros,
    required this.debitoPessoal,
  });

  double get total =>
      creditoCompart +
      creditoPessoal +
      debitoCompart +
      debitoOutros +
      debitoPessoal;
}

/// Categoria que separa o débito da pessoa em "pessoal" e "outros". Comparação
/// normalizada porque a col F é texto livre.
const _kCategoriaPessoal = 'pessoal';

/// Linhas de débito que entram no acerto da pessoa, em três grupos.
///
/// **Todo** o débito que toca a pessoa entra — a coluna `Acerto` (col J) não
/// filtra mais nada aqui desde 2026-10-01. Antes só linhas marcadas `Sim`
/// contavam, e o card mostrava uma despesa onde havia cinco.
///
/// `outros` e `pessoal` são o mesmo conjunto de antes (rateio = a pessoa),
/// partido pela categoria: contas de casa que ela paga sozinha não são gasto
/// pessoal dela e o usuário quis as duas coisas somadas em separado.
class AcertoDebito {
  final List<ExpenseRow> compart;
  final List<ExpenseRow> outros;
  final List<ExpenseRow> pessoal;

  const AcertoDebito({
    required this.compart,
    required this.outros,
    required this.pessoal,
  });
}

bool _isPessoal(ExpenseRow r) =>
    r.categoria.trim().toLowerCase() == _kCategoriaPessoal;

AcertoDebito acertoDebitoRows(List<ExpenseRow> rows, Person person) {
  final debito = rows.where((r) => r.origem == kOrigemDebito);
  final daPessoa = debito.where((r) => r.rateio == person.name);
  return AcertoDebito(
    compart: debito.where((r) => r.rateio == kRateioCompartilhado).toList(),
    outros: daPessoa.where((r) => !_isPessoal(r)).toList(),
    pessoal: daPessoa.where(_isPessoal).toList(),
  );
}

AcertoBreakdown acertoBreakdown(List<ExpenseRow> rows, Person person) {
  final credito = rows.where((r) => r.origem == kOrigemCredito);
  final debito = acertoDebitoRows(rows, person);

  return AcertoBreakdown(
    creditoCompart: credito
        .where((r) => r.rateio == kRateioCompartilhado)
        .fold<double>(0, (s, r) => s + splitForPerson(r, person)),
    creditoPessoal: credito
        .where((r) => r.rateio == person.name)
        .fold<double>(0, (s, r) => s + splitForPerson(r, person)),
    debitoCompart: debito.compart
        .fold<double>(0, (s, r) => s + splitForPerson(r, person)),
    debitoOutros: debito.outros.fold<double>(0, (s, r) => s + r.valor),
    debitoPessoal: debito.pessoal.fold<double>(0, (s, r) => s + r.valor),
  );
}
