---
status: stable
last_updated: 2026-09-20
---

# Compart — Cartão compartilhado por categoria (Flutter, direção Bloom)

Página dedicada do Flutter para visualizar o total da fatura de cartão **por categoria**, com destaque para a porção compartilhada de cada uma. Substitui a sub-aba `Categoria` da [Consulta](consulta.md) do PWA.

> **Escopo:** apenas Flutter. PWA continua na sub-aba.

## Contexto

A despesa de cartão é categorizada (Mercado, Restaurante, Pessoal, etc.). Para revisar onde foi gasto e quanto entra no acerto compartilhado, esta página mostra todas as categorias em uma tabela com bar inline indicando proporção, e dois tiles superiores resumem `Total cartão` e `Total compartilhado`.

## Regras

### Inputs

- `monthData(currentMonth)` — fatura corrente. Sem chamadas extras.

### Layout

1. **Header** `ScreenHeader` com kicker "Cartão compartilhado" + título "Por categoria" + `MonthSelector`.
2. **2 tiles 2-col topo**:
   - `Total cartão` (Σ valores onde `origem == "Cartão"`).
   - `Total compartilhado` (Σ `splitForPerson` aplicado para `Metade`/`""` que vão para acerto). Tile com fundo gradient `violet15→sky15`.
3. **Tabela de categorias** dentro de um `BloomCard`:
   - Cabeçalho 3-col: `Categoria | Valor | %`.
   - Cada linha:
     - Bullet violeta + label da categoria.
     - Valor (mono).
     - Percentual sobre `total`.
     - Linha secundária abaixo: `Compart: R$ X` (mint se >0, dimmed senão).
     - Bar inline (atrás do conteúdo) com largura proporcional a `valor / max`.
     - **Tap abre o detalhamento** da categoria em `/categoria?nome=<label>` (chevron lilás ao lado do rótulo) — ver [categoria.md](categoria.md). Pós-2026-09-20.
   - Última linha: `Total | R$ X | 100,00%` (border-top destacado).

### Cálculo dos valores por categoria

```
groupBy(rows where origem == "Cartão", r => r.categoria)
.map(g => {
  label: g.key,
  value: Σ g.rows[i].valor,
  compart: Σ splitForCompart(r) // valor que vira fatura compartilhada
})
.sort(desc by value)
```

`splitForCompart`: aplica regra de [split-for-person](../rules/split-for-person.md) — quando `rateio == "Metade"`, metade vai para cada pessoa (logo, todo o valor é compartilhado). Quando `rateio == "Julio"`/`"Dani"`/`"Alzira"`, valor é pessoal (compart = 0).

### Loading / vazio

- Loading: 1 skeleton card grande com 3 linhas.
- Sem rows: tabela com 1 linha "Sem despesas neste mês."

## Edge cases

- **Categoria vazia (`""`)**: agrupa em uma linha "Sem categoria" (label literal `"—"`).
- **Categoria com valor 0:** ainda aparece (raro, mas possível pós-edit).
- **`max == 0`**: bars têm largura 0 (não dividir por zero).

## Implementações

- **Flutter:** [app/lib/features/compart/compart_page.dart](../../../app/lib/features/compart/compart_page.dart)
- **PWA:** sem equivalente direto — usa sub-aba `Categoria` em [consulta.md](consulta.md) com `CategoriaTable`.

## Specs relacionadas

- [../cards/categoria-table.md](../cards/categoria-table.md) — tabela equivalente no PWA
- [../rules/split-for-person.md](../rules/split-for-person.md)
- [../data/despesas-sheet.md](../data/despesas-sheet.md)
