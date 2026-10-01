---
status: stable
last_updated: 2026-09-20
---

# Compart — Cartão compartilhado por categoria (Flutter, direção Bloom)

> **Rótulo na barra inferior: "Categoria"** (pós-2026-10-01; era "Compart"). O nome interno da aba (`BloomTab.compart`) e desta spec não mudaram.

Página dedicada do Flutter para visualizar o total da fatura de cartão **por categoria**, com destaque para a porção compartilhada de cada uma. Substitui a sub-aba `Categoria` da [Consulta](consulta.md) do PWA.

> **Escopo:** apenas Flutter. PWA continua na sub-aba.

## Contexto

A despesa de cartão é categorizada (Mercado, Restaurante, Pessoal, etc.). Para revisar onde foi gasto e quanto entra no acerto compartilhado, esta página mostra todas as categorias em uma tabela com bar inline indicando proporção, e dois tiles superiores resumem `Total cartão` e `Total compartilhado`.

## Regras

### Inputs

- `monthData(currentMonth)` — fatura corrente. Sem chamadas extras.

### Layout

1. **Header** `ScreenHeader` com título "Por categoria" + `MonthSelector`. O kicker fixo "Cartão compartilhado" saiu em 2026-10-01 — a tela deixou de ser só de cartão quando ganhou o tile de débito.
2. **Grid 2×2 de tiles** (pós-2026-10-01):
   - `TOTAL CRÉDITO` — `Σ valor` onde `origem == "Crédito"`. Rotulado `TOTAL CARTÃO` até 2026-10-01; mesmo número.
   - `TOTAL DÉBITO` — `Σ valor` onde `origem == "Débito"`. Entrou no lugar do tile `PARCELADO`, que saiu desta tela (segue na [Início](inicio.md)).
   - `COMPARTILHADO` — `Σ valor` das linhas `Metade`, **recortado pelo filtro de origem** (ver abaixo). Sem filtro, soma as duas origens. Tile destacado.
   - `COMPARTILHADO / 2` — o anterior dividido por dois. Tile destacado.

### Filtro de origem (pós-2026-10-01)

Os dois tiles de cima (`TOTAL CRÉDITO` e `TOTAL DÉBITO`) são **selecionáveis**. Estado em `compartOrigemFilterProvider` (sessão), `null` = sem seleção.

1. Tocar num tile marca; tocar nele de novo desmarca; marcar um desmarca o outro.
2. Os **dois tiles de baixo** passam a contar só a origem marcada, e o rótulo vira `COMPARTILHADO CRÉDITO` / `COMPARTILHADO DÉBITO`. Sem seleção, somam as duas origens.
3. **Chegando pela [Início](inicio.md)** (coluna do Comparativo), o tile correspondente já vem marcado — é o que faz o número da coluna fechar com o `COMPARTILHADO / 2` desta tela.
4. **Chegando pela barra inferior**, o filtro é limpo: navegação sem contexto não marca nada.

A **tabela de categorias não é afetada** pelo filtro — segue listando Crédito por categoria. Decisão pendente de confirmação do usuário.
3. **Tabela de categorias** dentro de um `BloomCard`:
   - Cabeçalho 3-col: `Categoria | Valor | %`.
   - Cada linha:
     - Bullet violeta + label da categoria.
     - Valor (mono).
     - Percentual sobre `total`.
     - Linha secundária abaixo: `Compart: R$ X` (mint se >0, dimmed senão).
     - Bar inline (atrás do conteúdo) com largura proporcional a `valor / max`.
     - Rótulo e chevron ficam num **único slot flexível** (`Expanded` com `Flexible` dentro). `Flexible` e `Spacer` lado a lado dividiriam o espaço livre entre si (flex 1 cada) e as colunas de valor/% mudariam de posição conforme o tamanho do rótulo.
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
