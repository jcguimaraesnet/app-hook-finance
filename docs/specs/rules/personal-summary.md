---
status: stable
last_updated: 2026-05-29
---

# personalSummary — 4 indicadores de despesa pessoal por pessoa

Calcula os quatro indicadores exibidos no topo da página [Detalhe](../pages/detalhe.md) para uma pessoa (`Júlio` ou `Dani`) e um conjunto de linhas do mês.

## Contexto

A página de despesas pessoais precisa responder, num relance, quatro perguntas distintas sobre a pessoa selecionada:

1. Quanto, no total, é "meu" este mês — incluindo qualquer origem (Crédito e Débito).
2. Quanto foi no Crédito pessoal (subset histórico, equivalente ao bucket `pessoal` de [bucket-deltas.md](bucket-deltas.md)).
3. Quanto disso é parcelado no mês corrente (afeta o "cheio" de hoje).
4. Quanto vai retornar como parcela no próximo mês (projeção de compromisso futuro).

Sem essa decomposição o usuário não consegue diferenciar "esse mês foi caro" de "esse mês foi caro **por parcela**", informação crítica pra planejar.

## Regras

### Inputs

- `rows: ExpenseRow[]` — fatura do mês corrente.
- `person: Person` — `Julio` ou `Dani`.

### Filtros base

Todos os 4 cálculos compartilham `r.rateio === person.name` (string exata, case-sensitive).

### Fórmulas

```text
totalPessoal     = Σ r.valor  onde  rateio = person  (qualquer origem)
cartaoPessoal    = Σ r.valor  onde  rateio = person  E  origem = "Crédito"
parceladoAtual   = Σ r.valor  onde  rateio = person  E  origem = "Crédito"  E  parcelaTotal(r.parcela) > 1
parceladoProx    = Σ r.valor  onde  rateio = person  E  origem = "Crédito"  E  parcelaTotal(r.parcela) > 1  E  parcelaAtual(r.parcela) < parcelaTotal(r.parcela)
```

- `parcelaTotal("X/Y")` → `int Y`. Vazio/legado retorna 1. Ver [parcela-format.md](parcela-format.md).
- `parcelaAtual("X/Y")` → `int X`. Vazio retorna 1.

### Interpretação

- `parceladoAtual` inclui a **última** parcela (X=Y) — ela faz parte da fatura corrente.
- `parceladoProx` **exclui** a última parcela — ela não vai gerar uma nova no mês seguinte.
- Quando `parcelaTotal ≤ 1`, a linha é tratada como à vista e fica fora dos dois últimos campos.

## Edge cases

- `rows = []` → todos os 4 valores = 0.
- `r.parcela = "1"` (legado, sem `/`) → `parcelaTotal = 1`, não conta como parcelado.
- `r.parcela = "1/1"` → `parcelaTotal = 1`, idem (à vista).
- `r.parcela = "3/3"` → entra em `parceladoAtual`, não entra em `parceladoProx` (última parcela).
- `r.origem` diferente de `"Crédito"` (ou seja, `"Débito"`) → conta só em `totalPessoal`.
- `r.rateio = "Metade"` ou rateio de outra pessoa → ignorado para essa person em todos os 4 campos.

## Implementações

- **Flutter:** [app/lib/core/rules/personal_summary.dart](../../../app/lib/core/rules/personal_summary.dart).
- **PWA:** sem equivalente (PWA React está congelada — usa o `web/src/pages/DetalhePage.tsx` legado).
- **Backend:** sem equivalente (regra de produto, vive no client).

## Specs relacionadas

- [parcela-format.md](parcela-format.md) — formato `X/Y` e helpers.
- [bucket-deltas.md](bucket-deltas.md) — buckets compart/pessoal/contas (relacionado a `cartaoPessoal`).
- [../pages/detalhe.md](../pages/detalhe.md) — consumidor único.
- [../data/despesas-sheet.md](../data/despesas-sheet.md) — schema das colunas.
