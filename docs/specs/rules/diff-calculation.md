---
status: stable
last_updated: 2026-09-20
---

# diffCalculation — diferença entre pessoas no mês

Calcula quanto uma pessoa pagou a mais (ou a menos) que a outra em despesas que entram no acerto: as linhas de **Débito** do mês.

## Contexto

Aparece como o "Δ" colorido nos cards de pessoa em **Consulta/Pessoal** ([PersonCard](../cards/person-card.md)) E em **Acerto** ([AcertoCard](../cards/acerto-card.md)). Hoje a fórmula está duplicada nos dois arquivos. Histórico mostra divergência futura possível — esta spec é a fonte autoritativa que ambos devem importar.

## Regras

`diffCalculation(rows, person) → number`:

1. Sejam `me = person`, `other = (person === "Julio" ? "Dani" : "Julio")`.
2. `meu = Σ splitForPerson(r, me)` para `r` com `origem === "Débito"`.
3. `outro = Σ splitForPerson(r, other)` para `r` com `origem === "Débito"`.
4. Retorna `meu - outro` (pode ser negativo).

A regra **considera todas** as linhas de Débito do mês — inclusive as **sem `acerto = "Sim"`**. Razão: o número precisa bater entre Consulta e Acerto, e Consulta exibe todas as linhas de Débito do mês (ela não filtra por Acerto).

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
- **Mês com Débito mas só de uma pessoa:** `outro = 0`. Diff = `meu`. (Ex.: novo mês onde só inseriram `"Plano de Saúde (Julio)"`.)
- **Toggle do diff:** controle de visibilidade vive em `sessionStorage` (`hook-finance-diff-${person}`). Default `true`. Implementação em cada card, não nesta regra. Ver [../state/persistence.md](../state/persistence.md).
- **`splitForPerson` retorna 0** para linhas com `rateio` não pertinente: contribuição zero, regra não muda.
- **`origem = "Débito"` mas `rateio = "Metade"`:** acontece raramente; `splitForPerson` divide ao meio para ambos, então `meu - outro = 0` para essa linha. Esperado.

## Implementações

- **Hoje duplicado:**
  - [web/src/components/PersonCard.tsx:62-78](../../../web/src/components/PersonCard.tsx)
  - [web/src/pages/AcertoPage.tsx:78-99](../../../web/src/pages/AcertoPage.tsx)
- **Após Onda 2:** `web/src/core/rules/diffCalculation.ts` (única fonte; ambos os arquivos importam).
- **Flutter:** `app/lib/core/rules/diff_calculation.dart` (Onda 4).

```ts
// Reference impl (após a migração de Origem)
export function diffCalculation(rows: Row[], person: Person): number {
  const other: Person = person === "Julio" ? "Dani" : "Julio";
  let meu = 0;
  let outro = 0;
  for (const r of rows) {
    if (r.origem !== "Débito") continue;
    meu += splitForPerson(r, person);
    outro += splitForPerson(r, other);
  }
  return meu - outro;
}
```
## Specs relacionadas

- [split-for-person.md](split-for-person.md)
- [../cards/person-card.md](../cards/person-card.md)
- [../cards/acerto-card.md](../cards/acerto-card.md)
- [../state/persistence.md](../state/persistence.md) — toggle de visibilidade do diff
