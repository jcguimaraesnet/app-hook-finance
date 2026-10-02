// Spec: docs/specs/cards/acerto-card.md
// Mudanças aqui DEVEM começar pela spec.

import '../rateio.dart';
import '../origem.dart';
import '../types.dart';
import 'categoria_rows.dart';
import 'split_for_person.dart';

/// As quatro linhas agrupadoras do card de Acerto, seus dois subtotais e o
/// total da pessoa.
///
/// Existe porque o número grande do topo ("X TRANSFERE PARA Y") e o "Total
/// Pessoal" do card são o mesmo valor e estavam calculados em dois lugares. Em
/// 2026-10-01 a linha de débito compartilhado entrou no card e a cópia do topo
/// não acompanhou: a tela passou a mostrar R$ 4.566,65 em cima e R$ 7.883,06
/// embaixo.
class AcertoBreakdown {
  /// Lançamentos que a **outra** pessoa deve reembolsar (col J com o nome
  /// dela). Saem dos outros quatro grupos e formam o primeiro bloco da tabela.
  final double reembolso;

  final double creditoCompart;
  final double creditoPessoal;
  final double debitoCompart;
  final double debitoPessoal;

  const AcertoBreakdown({
    required this.reembolso,
    required this.creditoCompart,
    required this.creditoPessoal,
    required this.debitoCompart,
    required this.debitoPessoal,
  });

  /// Subtotal das duas linhas de crédito, exibido logo abaixo delas no card.
  double get credito => creditoCompart + creditoPessoal;

  /// Subtotal das duas linhas de débito. A tabela é simétrica desde 2026-10-02:
  /// compartilhado + pessoal em cada metade, cada uma fechada pelo seu subtotal.
  double get debito => debitoCompart + debitoPessoal;

  double get total => reembolso + credito + debito;

  /// O que a pessoa transfere — o número grande do topo da tela.
  ///
  /// **Não é o `total`**: desde 2026-10-02 o débito fica de fora, por pedido do
  /// usuário. O que ele paga em conta de casa já saiu da conta dele no mês; o
  /// que se transfere é o reembolso mais a fatura do cartão. O card continua
  /// mostrando o `total` no rodapé, que é outra pergunta — quanto a pessoa
  /// gastou. Os dois números divergem de propósito: já divergiram por acidente
  /// (4.566,65 em cima, 7.883,06 embaixo) e por isso saem os dois daqui.
  double get transferencia => reembolso + credito;
}

/// Categoria que o cálculo da Diferença ignora. Comparação normalizada porque a
/// col F é texto livre.
const _kCategoriaPessoal = 'pessoal';

bool _isCategoriaPessoal(ExpenseRow r) =>
    r.categoria.trim().toLowerCase() == _kCategoriaPessoal;

/// Linhas de débito que entram no acerto da pessoa, em dois grupos.
///
/// **Todo** o débito que toca a pessoa entra — a coluna `Acerto` (col J) não
/// filtra mais nada aqui desde 2026-10-01. Antes só linhas marcadas `Sim`
/// contavam, e o card mostrava uma despesa onde havia cinco.
///
/// Entre 2026-10-01 e 2026-10-02 `pessoal` foi partido em dois grupos pela
/// categoria (`Débito (outros)` + `Débito (pessoal)`). Voltou a ser um só para
/// a tabela ficar simétrica com as duas linhas de crédito; o corte por
/// categoria sobreviveu só onde muda número, em [debitoParaDiferenca].
class AcertoDebito {
  final List<ExpenseRow> compart;
  final List<ExpenseRow> pessoal;

  const AcertoDebito({required this.compart, required this.pessoal});
}

/// Lançamentos do acerto da pessoa marcados para a **outra** reembolsar.
///
/// Col J passou a guardar quem reembolsa em 2026-10-02 (antes era `"Sim"` =
/// "entra no acerto"). No card do Júlio aparecem as linhas marcadas `Dani`, e
/// vice-versa: é o que a outra pessoa deve devolver. Elas saem dos quatro
/// grupos normais — a mesma despesa não pode ser contada nos dois lugares.
///
/// Valor por `splitForPerson`, como em todo o card: uma linha `Compartilhado`
/// entra pela metade. A linha marcada com o nome da **própria** pessoa não é
/// reembolso dela — fica onde estava.
List<ExpenseRow> acertoReembolsos(List<ExpenseRow> rows, Person person) => rows
    .where((r) => splitForPerson(r, person) != 0)
    .where((r) => r.acerto.trim() == person.other.name)
    .toList();

bool _ehReembolso(ExpenseRow r, Person person) =>
    r.acerto.trim() == person.other.name;

AcertoDebito acertoDebitoRows(List<ExpenseRow> rows, Person person) {
  final debito = rows.where(
      (r) => r.origem == kOrigemDebito && !_ehReembolso(r, person));
  return AcertoDebito(
    compart: debito.where((r) => r.rateio == kRateioCompartilhado).toList(),
    pessoal: debito.where((r) => r.rateio == person.name).toList(),
  );
}

/// Débito da pessoa **fora** da categoria `Pessoal` — a base da pílula
/// "Diferença". Ver [diffCalculation].
///
/// Era a linha `Débito (outros)` da tela até 2026-10-02. A linha sumiu na
/// simetrização da tabela, a regra ficou: Dízimo e Previdência não são despesa
/// da casa que um pagou pelo outro, e tirá-las foi uma decisão explícita do
/// usuário — desfazê-la junto com um ajuste de layout mudaria dinheiro sem
/// ninguém ter pedido.
/// Linhas marcadas para a outra pessoa reembolsar também ficam de fora, por
/// tabela: `acertoDebitoRows` já as removeu. Coerente — o que vai ser devolvido
/// é acertado no bloco Reembolsos, não na pílula.
List<ExpenseRow> debitoParaDiferenca(List<ExpenseRow> rows, Person person) =>
    acertoDebitoRows(rows, person)
        .pessoal
        .where((r) => !_isCategoriaPessoal(r))
        .toList();

/// Uma categoria dentro do crédito compartilhado, já na parte da pessoa.
class AcertoCategoria {
  final String categoria;
  final double valor;

  const AcertoCategoria({required this.categoria, required this.valor});
}

/// Quebra de uma das duas linhas de crédito **por categoria**, maior primeiro.
///
/// As duas são fatura de cartão: compras miúdas, onde a lista de lançamentos
/// não responde o que se pergunta olhando o acerto — em que foi o dinheiro. As
/// de débito, que são contas com nome próprio, seguem listando lançamento.
///
/// `compartilhado: true` pega o rateio `Compartilhado` (metade da pessoa);
/// `false`, o rateio da própria pessoa (valor cheio). `splitForPerson` já faz
/// essa distinção, então a soma bate exatamente com `creditoCompart` ou
/// `creditoPessoal` do subtotal que abre o grupo.
List<AcertoCategoria> acertoCreditoCategorias(
  List<ExpenseRow> rows,
  Person person, {
  required bool compartilhado,
}) {
  final rateioAlvo = compartilhado ? kRateioCompartilhado : person.name;
  final porCategoria = <String, double>{};
  for (final r in rows) {
    if (r.origem != kOrigemCredito) continue;
    if (r.rateio != rateioAlvo) continue;
    if (_ehReembolso(r, person)) continue; // foi para o bloco Reembolsos
    final key = categoriaLabel(r);
    porCategoria[key] = (porCategoria[key] ?? 0) + splitForPerson(r, person);
  }
  final out = porCategoria.entries
      .map((e) => AcertoCategoria(categoria: e.key, valor: e.value))
      .toList()
    ..sort((a, b) => b.valor.compareTo(a.valor));
  return out;
}

AcertoBreakdown acertoBreakdown(List<ExpenseRow> rows, Person person) {
  final credito = rows.where(
      (r) => r.origem == kOrigemCredito && !_ehReembolso(r, person));
  final debito = acertoDebitoRows(rows, person);

  return AcertoBreakdown(
    reembolso: acertoReembolsos(rows, person)
        .fold<double>(0, (s, r) => s + splitForPerson(r, person)),
    creditoCompart: credito
        .where((r) => r.rateio == kRateioCompartilhado)
        .fold<double>(0, (s, r) => s + splitForPerson(r, person)),
    creditoPessoal: credito
        .where((r) => r.rateio == person.name)
        .fold<double>(0, (s, r) => s + splitForPerson(r, person)),
    debitoCompart: debito.compart
        .fold<double>(0, (s, r) => s + splitForPerson(r, person)),
    debitoPessoal: debito.pessoal.fold<double>(0, (s, r) => s + r.valor),
  );
}
