---
status: stable
last_updated: 2026-09-20
---

# Categoria — detalhamento de uma categoria do Compart

Drill-down de uma linha da tabela do [Compart](compart.md). Lista os lançamentos de Crédito daquela categoria no mês corrente.

Só existe no Flutter (Bloom). A PWA legada não tem essa tela.

## Contexto

A tabela do Compart mostra quanto foi gasto por categoria, mas não *no quê*. Descobrir o que compõe `Alimentação — R$ 2.100` exigia abrir Lançamentos e filtrar com o olho, ou ir na planilha.

## Regras

### Rota

`/categoria?nome=<categoria>`, empilhada sobre o Compart (tem back). O nome vai codificado (`Uri.encodeQueryComponent`) — categorias têm acento e espaço.

### Inputs

`monthData(currentMonth)`. Nenhum endpoint extra.

### Filtragem

`categoriaRowsForMonth(rows, categoria)` — ver [../rules/categoria-rows.md](../rules/categoria-rows.md). Ordenada por `dataRef` descendente via `parseBrRefDate`.

### Tiles

| Tile | Valor |
|---|---|
| **TOTAL** | `Σ valor` — o mesmo número da coluna Valor na linha clicada. |
| **COMPARTILHADO** | `Σ valor/2` das linhas `Metade` — o mesmo `Compart: R$ X` da linha clicada. |

Os dois reconciliam com a tabela por construção: a página e a tabela usam a mesma regra.

### Render

- `ScreenHeader` com back, kicker "Categoria", título = nome da categoria e `MonthSelector`.
- Lista de `RecentEntryRow` com `hideCategory: true` — todas são da mesma categoria, repeti-la não acrescenta nada.
- **Tap edita o lançamento**, como em [detalhe.md](detalhe.md) e [debito.md](debito.md). Ao salvar, invalida `monthDataProvider` e `lastEntriesProvider`.

### Loading / vazio

- Loading: spinner no lugar dos tiles.
- Sem linhas: `"Sem lançamentos nesta categoria."`.

## Edge cases

- **Categoria vazia:** a tabela do Compart agrupa as linhas sem categoria sob `—`, e o drill-down recebe esse mesmo `—`. `categoriaLabel` é a fonte única dessa conversão nos dois lados.
- **Editar muda a categoria ou a origem:** a linha some da lista ao recarregar. Esperado — saiu do grupo.
- **Categoria que não existe no mês** (link antigo, mês trocado pelo `MonthSelector`): lista vazia com a mensagem. Não é erro.

## Implementações

- **Flutter:** [app/lib/features/categoria/categoria_page.dart](../../../app/lib/features/categoria/categoria_page.dart); rota em [app/lib/app.dart](../../../app/lib/app.dart).
- **Origem do tap:** [compart.md](compart.md).

## Specs relacionadas

- [../rules/categoria-rows.md](../rules/categoria-rows.md) — filtro e totais
- [compart.md](compart.md) — tela de onde se navega
- [../cards/recent-entry-row.md](../cards/recent-entry-row.md)
