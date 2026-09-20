---
status: stable
last_updated: 2026-09-20
---

# bucketKey

Mapeia uma `Row` para uma chave de agrupamento usada em cards/charts. Define, em particular, o **par "Cartão (compartilhado)" vs "Cartão (pessoal)"** em função do `rateio`.

## Contexto

Cards como [PersonCard](../cards/person-card.md) e [AcertoCard](../cards/acerto-card.md) agrupam linhas para mostrar totais por categoria conceitual (não por `categoria` da planilha — por `origem` desambiguada por `rateio`). Esse mapeamento é ponto recorrente de drift; centralizar.

## Regras

`bucketKey(row) → string`:

1. Se `row.origem === "Crédito"`:
   - Se `row.rateio === "Metade"`, retorna `"Crédito (compartilhado)"`.
   - Caso contrário (qualquer outro rateio, inclusive vazio), retorna `"Crédito (pessoal)"`.
2. Caso contrário, retorna `row.origem` literalmente — hoje só `"Débito"`, já que o enum da col E tem dois valores desde 2026-09-20 (ver [../data/despesas-sheet.md](../data/despesas-sheet.md)). A regra segue genérica para aguentar linha legada não migrada.

A chave volta como **string com a label exata** que aparece na UI. Não introduzir uma camada de tradução (`"cartao_shared"` → `"Cartão (compartilhado)"`) — a chave é a label.

## Edge cases

- **`origem` vazio:** retorna `""`. Componentes devem tratar como bucket "(sem origem)" se quiserem exibir, mas pela regra a chave é `""` mesmo.
- **`origem = "Crédito"` E `rateio = ""`:** cai em `"Crédito (pessoal)"` pela regra 1. Hoje no PWA isso aparece em `RateioChart` como `"(sem rateio)"`, mas no `PersonCard` cai em `"Crédito (pessoal)"` — note que o **bucket** está alinhado, é só a label do RateioChart que difere ([../cards/rateio-chart.md](../cards/rateio-chart.md) usa label diferente).
- **`origem` desconhecida** (ex.: linha legada com `"Outros"`): retorna `"Outros"`. Card decide se renderiza ou ignora.

## Ordem canônica de buckets

Quando a UI lista buckets, a ordem padrão é:

```
1. Crédito (compartilhado)
2. Crédito (pessoal)
3. Débito
```

Buckets fora dessa lista vão ao final, em ordem de inserção. Implementações devem expor essa ordem como constante (`BUCKET_ORDER`).

## Implementações

- **PWA atual (inline):** [web/src/components/PersonCard.tsx:20-27](../../../web/src/components/PersonCard.tsx) — será movido para `web/src/core/rules/bucketKey.ts` na Onda 2 e a constante `BUCKET_ORDER` para `web/src/core/constants.ts`.
- **Flutter:** `app/lib/core/rules/bucket_key.dart` (Onda 4).

```ts
// Reference impl
export function bucketKey(row: Row): string {
  if (row.origem === "Crédito") {
    return row.rateio === "Metade"
      ? "Crédito (compartilhado)"
      : "Crédito (pessoal)";
  }
  return row.origem;
}

export const BUCKET_ORDER = [
  "Crédito (compartilhado)",
  "Crédito (pessoal)",
  "Débito",
] as const;
```

## Specs relacionadas

- [split-for-person.md](split-for-person.md)
- [../cards/person-card.md](../cards/person-card.md)
- [../cards/acerto-card.md](../cards/acerto-card.md)
- [../cards/rateio-chart.md](../cards/rateio-chart.md)
