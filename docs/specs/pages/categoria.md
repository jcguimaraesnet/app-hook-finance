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

`categoriaRowsForMonth(rows, categoria, origem: ...)` — chamada **duas vezes**, uma por origem, para montar os dois grupos. Ver [../rules/categoria-rows.md](../rules/categoria-rows.md). Cada grupo ordenado por `dataRef` descendente via `parseBrRefDate`.

### Tiles

Grid 2×2:

| Tile | Valor |
|---|---|
| **CRÉDITO** | `Σ valor` do grupo de Crédito — o mesmo número da coluna Valor na linha clicada. |
| **DÉBITO** | `Σ valor` do grupo de Débito. Não existe na tabela do Compart, que é só de Cartão. |
| **COMPARTILHADO** | `Σ valor/2` das linhas `Compartilhado` das **duas** origens. |
| **TOTAL** | Crédito + Débito. |

O tile **CRÉDITO** é o que reconcilia com a tabela de onde se clicou — por isso `origem` é parâmetro obrigatório da regra, para ninguém somar as duas origens por acidente e divergir do número clicado.

### Render

- `ScreenHeader` com back, kicker "Categoria", título = nome da categoria e `MonthSelector`.
- **Dois grupos** (pós-2026-10-01), nesta ordem: **Crédito** e **Débito**. Cada um com cabeçalho `<nome> (N)` + subtotal à direita, e seu próprio card de lista.
- Lista de `RecentEntryRow` com `hideCategory: true` — todas são da mesma categoria, repeti-la não acrescenta nada.
- **Tap edita o lançamento**, como em [detalhe.md](detalhe.md) e [debito.md](debito.md). Ao salvar, invalida `monthDataProvider` e `lastEntriesProvider`.

### Loading / vazio

- Loading: spinner no lugar dos tiles.
- Sem linhas: cada grupo tem seu vazio — `"Sem lançamentos de crédito nesta categoria."` / `"...de débito..."`. Um grupo vazio não esconde o outro.

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
