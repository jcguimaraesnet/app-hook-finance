---
status: stable
last_updated: 2026-05-07
---

# PersonCard — card de pessoa em Consulta

> **Congelado (PWA legada).** Descreve a PWA React em `web/`, que não é mais deployada. Os nomes de origem citados aqui (`Cartão`, `Pix (contas)`, `Empregados`) são o enum **pré-2026-09-20**; a col E hoje é `Crédito` | `Débito` — ver [../data/despesas-sheet.md](../data/despesas-sheet.md).

Card que mostra, para uma pessoa (`Júlio` ou `Dani`), o resumo das despesas do mês corrente agrupadas por bucket, com totais e %.

## Contexto

Exibido em pares (Júlio + Dani) na aba "Mês" de Consulta (ou na vista PC sem sub-tabs). Cada card mostra quanto a pessoa pagou em Cartão (compartilhado), Cartão (pessoal), Pix (contas), Pessoal, Empregados — e um Δ no header com a diferença em relação ao outro.

## Regras

### Inputs

- `person`: `"Julio" | "Dani"`.
- `rows`: `Row[]` do mês atual (não filtrado — o card filtra o que precisa).

### Agregação

1. Para cada `row` em `rows`:
   - `v = splitForPerson(row, person)` ([../rules/split-for-person.md](../rules/split-for-person.md))
   - Se `v === 0`, ignora.
   - Senão, soma `v` no bucket `bucketKey(row)` ([../rules/bucket-key.md](../rules/bucket-key.md)).
2. `total = soma de todos os buckets`.

### Ordem de exibição dos buckets

Usa `BUCKET_ORDER` ([../rules/bucket-key.md](../rules/bucket-key.md)). Buckets fora dessa lista vão depois, em ordem alfabética/inserção. Buckets com valor 0 não renderizam.

### Linhas da tabela

| Coluna | Conteúdo |
|---|---|
| Despesas agrupadas | label do bucket (ex.: `"Cartão (compartilhado)"`) |
| Valor (R$) | `formatMoney(v)` |
| % | `formatPct(v / total)` |

Linha final **Total Pessoal** com `formatMoney(total)` e `100%`.

### Header — diff

- Mostra "Júlio" ou "Dani" centralizado.
- À direita do título, valor do diff: `${sinal} R$ ${formatMoney(Math.abs(diff))}`. Sinal `+` se ≥ 0, `−` se < 0.
  - `diff = diffCalculation(rows, person)` ([../rules/diff-calculation.md](../rules/diff-calculation.md)).
- À direita do diff, botão `Δ` que toggle visibilidade do diff. Visibilidade persistida em `sessionStorage` por pessoa — ver [../state/persistence.md](../state/persistence.md).
- Cor do diff: azul se ≥ 0, `text-negative` (vermelho/laranja) se < 0.

## Edge cases

- **Mês vazio** (`rows = []`): renderiza header com Δ "+ R$ 0,00", tabela com só "Total Pessoal: 0,00 / —". (`pct = total ? v/total : 0`; total final mostra `—` se zero — verificar visualmente.)
- **Pessoa sem despesas mas mês tem dados:** card aparece com Total 0 e nenhuma linha, mas mostra Δ correto (Δ é independente da agregação por bucket — ele compara Pix/Contas, não Cartão).
- **Bucket "Pessoal" presente:** renderiza normalmente. Note que [historicalSummary](../api/endpoints.md) **exclui** "Pessoal" do total geral; aqui o card NÃO exclui — mostra tudo.
- **Loading:** componente parent (ConsultaPage) renderiza `CardSkeleton` em vez do PersonCard. PersonCard sempre assume `rows` carregado.

## Implementações

- **PWA atual:** [web/src/components/PersonCard.tsx](../../../web/src/components/PersonCard.tsx)
- **Após Onda 2:** mesmo arquivo, mas usando `bucketKey`, `BUCKET_ORDER`, `splitForPerson`, `diffCalculation` de `web/src/core/`.
- **Flutter:** `app/lib/widgets/person_card.dart` (Onda 5).

## Specs relacionadas

- [../rules/split-for-person.md](../rules/split-for-person.md)
- [../rules/bucket-key.md](../rules/bucket-key.md)
- [../rules/diff-calculation.md](../rules/diff-calculation.md)
- [../state/persistence.md](../state/persistence.md) — toggle Δ
- [../pages/consulta.md](../pages/consulta.md)
- [acerto-card.md](acerto-card.md) — variante usada em Acerto
