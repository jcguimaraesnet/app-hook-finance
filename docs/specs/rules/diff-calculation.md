---
status: stable
last_updated: 2026-10-01
---

# diffCalculation — diferença entre pessoas no mês

Calcula quanto uma pessoa pagou a mais (ou a menos) que a outra na linha **Débito (outros)** do card de Acerto.

## Contexto

Aparece como o "Δ" colorido nos cards de pessoa em **Consulta/Pessoal** ([PersonCard](../cards/person-card.md)) E em **Acerto** ([AcertoCard](../cards/acerto-card.md)). Hoje a fórmula está duplicada nos dois arquivos. Histórico mostra divergência futura possível — esta spec é a fonte autoritativa que ambos devem importar.

## Regras

`diffCalculation(rows, person) → number`:

1. Sejam `me = person`, `other = (person === "Julio" ? "Dani" : "Julio")`.
2. `meu = Σ valor` de `acertoDebitoRows(rows, me).outros`.
3. `outro = Σ valor` de `acertoDebitoRows(rows, other).outros`.
4. Retorna `meu - outro` (pode ser negativo).

Ou seja: `origem === "Débito"` E `rateio === <pessoa>` E `categoria !== "Pessoal"` E a linha **não** está marcada para a outra pessoa reembolsar. Ver [../pages/acerto.md](../pages/acerto.md).

⚠️ **O número não corresponde mais a nenhuma linha da tela.** De 2026-10-01 a 2026-10-02 ele era exatamente a diferença entre as duas linhas `Débito (outros)`; essa linha sumiu quando a tabela foi simetrizada. A regra do dinheiro ficou como estava **de propósito**: tirar a categoria `Pessoal` foi uma decisão explícita do usuário, e desfazê-la junto com um ajuste de layout mudaria dinheiro sem ninguém ter pedido. Hoje o pill é **menor** que a diferença entre os dois `Débito (pessoal)` exibidos.

A col J não filtra o que entra no acerto; desde 2026-10-02 ela só move a linha para o bloco Reembolsos — e o que foi para lá sai desta conta por tabela, já que `acertoDebitoRows` o removeu. Coerente: o que vai ser devolvido é acertado naquele bloco, não na pílula. Em 2026-10-02 isso não mudou nenhum número, porque nenhuma linha da planilha tinha ainda um nome na col J.

### O que mudou em 2026-10-01

Antes somava `splitForPerson` sobre **todo** o Débito que tocava cada pessoa. Duas consequências que o usuário pediu para remover:

- as linhas de categoria `Pessoal` (Dízimo, Previdência) entravam na conta, embora não sejam despesa da casa que um pagou pelo outro;
- o número do pill não correspondia a nenhuma linha visível da tabela, então não dava para conferir de onde vinha.

Agora o pill é a subtração de dois números que estão na própria tela. Efeito na fatura 06/11/2026: de **R$ 194,42** para **R$ 155,58** (2.100,00 da Dani − 1.944,42 do Júlio).

As linhas `Compartilhado` continuam fora: já são metade de cada um e se cancelariam.

### Por que o ramo `monthHasPix` sumiu (2026-09-20)

Até a migração de Origem a regra tinha dois braços: se o mês tivesse `Pix (contas)`, somava só Pix; senão somava `Contas` + `Empregados`. Os três viraram `Débito` e o ramo perdeu sentido.

Isso **não mudou nenhum número**, e não por sorte: os dois conjuntos nunca coexistiram no mesmo mês. A planilha usou `Contas`+`Empregados` até a fatura 06/04/2026 e `Pix (contas)` de 06/05/2026 em diante — o `monthHasPix` era, na prática, um seletor de era. Conferido nos 12 meses da planilha antes de migrar: diff idêntico em 12/12.

## Sinal e cor (decisão de display)

Display dos cards combina o sinal com a cor:

- `diff >= 0` → sinal `"+"`, cor azul (`text-[#2c5aa0]` no PWA).
- `diff < 0` → sinal `"−"`, cor `text-negative` no PWA.

O valor exibido é sempre `Math.abs(diff)`, prefixado com o sinal e `R$ `. Cor e sinal pertencem ao card, não a essa regra — mas a regra precisa retornar o número com sinal preservado.

## Edge cases

- **Mês completamente vazio:** `meu = outro = 0`, diff = 0, sinal `"+"`, exibe `+ R$ 0,00`.
- **Mês com `Débito (outros)` de só uma pessoa:** `outro = 0`. Diff = `meu`.
- **Mês em que todo o Débito individual é de categoria `Pessoal`:** diff = 0, mesmo havendo débito dos dois. Esperado: nenhum dos dois pagou despesa da casa pelo outro.
- **Toggle do diff:** controle de visibilidade vive em `sessionStorage` (`hook-finance-diff-${person}`). Default `true`. Implementação em cada card, não nesta regra. Ver [../state/persistence.md](../state/persistence.md).
- **`splitForPerson` retorna 0** para linhas com `rateio` não pertinente: contribuição zero, regra não muda.
- **`origem = "Débito"` mas `rateio = "Compartilhado"`:** a linha não entra em `outros` (que exige `rateio === <pessoa>`), então não afeta o diff. Antes entrava e se cancelava — mesmo resultado, por outro caminho.

## Implementações

- **Hoje duplicado:**
  - [web/src/components/PersonCard.tsx:62-78](../../../web/src/components/PersonCard.tsx)
  - [web/src/pages/AcertoPage.tsx:78-99](../../../web/src/pages/AcertoPage.tsx)
- **Após Onda 2:** `web/src/core/rules/diffCalculation.ts` (única fonte; ambos os arquivos importam).
- **Flutter:** `app/lib/core/rules/diff_calculation.dart` (Onda 4).

```dart
// Reference impl (pós-2026-10-01)
double diffCalculation(List<ExpenseRow> rows, Person person) {
  double outros(Person p) =>
      acertoDebitoRows(rows, p).outros.fold<double>(0, (s, r) => s + r.valor);

  return outros(person) - outros(person.other);
}
```
## Specs relacionadas

- [../pages/acerto.md](../pages/acerto.md) — de onde sai `Débito (outros)`
- [split-for-person.md](split-for-person.md)
- [../cards/person-card.md](../cards/person-card.md)
- [../cards/acerto-card.md](../cards/acerto-card.md)
- [../state/persistence.md](../state/persistence.md) — toggle de visibilidade do diff
