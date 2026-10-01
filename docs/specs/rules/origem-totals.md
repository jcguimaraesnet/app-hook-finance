---
status: stable
last_updated: 2026-10-01
---

# origemTotals — Crédito e Débito do mês somando as duas pessoas

Os dois tiles abaixo do card Comparação na [Início](../pages/inicio.md).

## Contexto

A Início inteira é a visão de **uma** pessoa: donut, Comparação e os tiles de topo mostram o que cabe ao Júlio **ou** à Dani. Faltava o número do casal por origem. Esses dois tiles são a única coisa da tela que não depende do seletor de pessoa.

## Regras

1. Para cada linha, o valor que entra é `splitForPerson(r, Julio) + splitForPerson(r, Dani)`:
   - `rateio === "Compartilhado"` → metade + metade = **valor cheio**;
   - `rateio === "Julio"` ou `"Dani"` → valor cheio para o dono;
   - `rateio === "Alzira"` ou vazio → **0**, a linha não entra.
2. A linha soma em `credito` se `origem === "Crédito"`, em `debito` se `origem === "Débito"`. Origem desconhecida não soma em lugar nenhum.
3. `total = credito + debito`.

### Invariante

`credito + debito` é **exatamente** `bucketsForPerson(rows, Julio).total + bucketsForPerson(rows, Dani).total` — os dois tiles de pessoa logo acima na mesma tela. Travado por teste em `app/test/core/rules/origem_totals_test.dart`.

Conferido na planilha em 06/11/2026: 4.194,86 + 12.027,25 = 16.222,11 = 7.339,05 (Júlio) + 8.883,06 (Dani).

## Edge cases

- **Mês só com linhas de terceiro:** os dois tiles mostram 0,00 — correto, nada disso é do casal.
- **Mês vazio:** `OrigemTotals.zero`.
- **Origem fora do enum** (linha legada não migrada): não entra. O app normaliza na leitura (`normalizeOrigem`), então só sobraria um valor realmente desconhecido — ver [../data/despesas-sheet.md](../data/despesas-sheet.md).

## Não confundir

O tile `TOTAL CRÉDITO` da aba [Categoria](../pages/compart.md) é outra conta: lá é o total **da tabela daquela tela** — só linhas `Compartilhado`, recortadas pelo tile de origem marcado. Os dois números divergem de propósito.

## Implementações

- **Flutter:** [app/lib/core/rules/origem_totals.dart](../../../app/lib/core/rules/origem_totals.dart)
- **PWA:** sem equivalente (tela não existe na PWA legada).

## Specs relacionadas

- [split-for-person.md](split-for-person.md) — o valor que cabe a uma pessoa por linha
- [bucket-deltas.md](bucket-deltas.md) — os buckets por pessoa, de onde vem a invariante
- [../pages/inicio.md](../pages/inicio.md)
