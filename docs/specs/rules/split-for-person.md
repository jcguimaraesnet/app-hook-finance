---
status: stable
last_updated: 2026-05-07
---

# splitForPerson

Dada uma linha (`Row`) e uma pessoa (`"Julio" | "Dani"`), retorna o valor que **cabe àquela pessoa** segundo o rateio.

## Contexto

A planilha registra apenas o `valor` cheio da despesa. Cada linha tem uma marca de `rateio` (col G) que diz como ela é dividida. Cards que mostram "quanto cada pessoa pagou no mês" precisam de uma única função autoritativa que aplique a regra. Sem ela, cada componente reinventa o cálculo e drift acontece (já aconteceu — `PersonCard` e `AcertoCard` reimplementavam a regra de bucketing por motivos similares).

## Regras

`splitForPerson(row, person) → number`:

1. Se `row.rateio === person`, retorna `row.valor` (cheio).
2. Se `row.rateio === "Compartilhado"` E `person ∈ {"Julio", "Dani"}`, retorna `row.valor / 2`.
3. Caso contrário, retorna `0`.

A função **não filtra por `origem`**. Quem chama decide se quer rodar só sobre Cartão, Pix, etc.

## Edge cases

- **`rateio` vazio (`""`):** retorna `0` para qualquer `person` (regras 1 e 2 não casam).
- **`rateio = "Alzira"`** com `person = "Julio"` ou `"Dani"`: retorna `0`.
- **`rateio = "Compartilhado"`** com `person = "Alzira"` (ou outro fora de Julio/Dani): a regra 2 só vale para Julio/Dani — retorna `0`. (Hoje `Person` é tipado como apenas `"Julio" | "Dani"`; se a tipagem for relaxada, manter essa restrição na implementação.)
- **`valor` negativo:** retorna o valor negativo cheio (regra 1) ou `valor / 2` (regra 2). Estornos seguem a mesma regra que despesas.
- **`valor === 0`:** retorna `0` em todas as regras (caso degenerado, sem efeito).

## Implementações

- **PWA atual:** [web/src/utils/splitForPerson.ts](../../../web/src/utils/splitForPerson.ts) (será movido para `web/src/core/rules/splitForPerson.ts` na Onda 2).
- **Flutter:** `app/lib/core/rules/split_for_person.dart` (Onda 4).

```ts
// PWA reference impl (idêntica ao código atual)
export function splitForPerson(row: Row, person: Person): number {
  if (row.rateio === person) return row.valor;
  if (row.rateio === "Compartilhado" && (person === "Julio" || person === "Dani")) {
    return row.valor / 2;
  }
  return 0;
}
```

## Specs relacionadas

- [bucket-key.md](bucket-key.md) — agrupamento que tipicamente acompanha esse cálculo
- [diff-calculation.md](diff-calculation.md) — usa splitForPerson sobre Pix/Contas/Empregados
- [../cards/person-card.md](../cards/person-card.md), [../cards/acerto-card.md](../cards/acerto-card.md), [../cards/rateio-chart.md](../cards/rateio-chart.md) — consumidores
