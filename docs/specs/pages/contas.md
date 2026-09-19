---
status: stable
last_updated: 2026-09-19
---

# Contas — lançamentos de contas por pessoa

Drill-down da coluna "Contas" do card Comparativo da [Início](inicio.md). Lista os lançamentos que **não** são de Cartão (`Pix (contas)`, `Contas`, `Empregados`, `Pessoal`) e que tocam a pessoa selecionada.

Só existe no Flutter (Bloom). A PWA legada em `web/` não tem essa tela e não vai ter — codebase congelado.

## Contexto

O card Comparativo mostra três números e só dois tinham para onde ir: Compartilhado tem a aba Compart, Pessoal tem o "Ver pessoal →". Contas era um número morto — o maior dos três em vários meses — e conferir o que tinha dentro exigia abrir a planilha.

A tela espelha [detalhe.md](detalhe.md) de propósito: mesma estrutura (header + toggle de pessoa + tiles + lista), para não inventar um terceiro padrão de drill-down.

## Regras

### Rota

`/contas?person=julio|dani`. Sem `person` (ou valor desconhecido) assume `julio`, igual a [detalhe.md](detalhe.md).

### Inputs

Lê `monthData(currentMonth)`. Não chama outros endpoints.

### Filtragem da lista

`contasRowsForPerson(rows, person)` — ver [../rules/contas-rows.md](../rules/contas-rows.md). Ordenada por `dataRef` **descendente** via `parseBrRefDate` (aceita col B com e sem hora — ver [../conventions.md](../conventions.md)).

### Tiles superiores (2 colunas)

| Tile | Valor |
|---|---|
| **SUA PARTE** | `Σ splitForPerson(r, person)` — **o mesmo número da coluna Contas do card Comparativo**. É o que reconcilia a tela com a origem do clique. |
| **TOTAL CHEIO** | `Σ r.valor` das linhas listadas. Maior que "sua parte" sempre que houver linha `Metade`. |

O segundo tile **só renderiza quando os dois valores diferem** (≥ R$ 0,005). Sem linha `Metade` nas contas do mês — o caso comum: em out/2026 todas as contas eram `Pix (contas)` com rateio individual — os dois números seriam idênticos e dois tiles iguais lado a lado parecem bug. Quando some, o tile restante é rotulado **TOTAL** em vez de "SUA PARTE", porque aí não há divisão nenhuma.

Dois tiles, não os quatro de [detalhe.md](detalhe.md): as outras duas métricas de lá (parcelado atual/próximo) são de Cartão e não existem aqui.

### Render

- `ScreenHeader` com back, kicker "Contas", título `<Person>` e `MonthSelector`.
- Toggle Júlio/Dani (mesmo `_PersonToggle` visual de [detalhe.md](detalhe.md)) — troca a pessoa sem sair da tela.
- Lista de `RecentEntryRow` mostrando o **valor cheio** da linha, não a parte da pessoa. Mesma convenção de [compart.md](compart.md) (lista cheia + tile dividido) e de [detalhe.md](detalhe.md).
  - `hideCategory: false` — aqui a categoria informa (contas têm categorias variadas), diferente de Despesas pessoais.
- **Tap edita o lançamento**: mesmo `EditDialog` de [lancamento.md](lancamento.md), igual a [detalhe.md](detalhe.md). Ao salvar, invalida `monthDataProvider` e `lastEntriesProvider`. Linha com `row < 2` fica sem `onTap`.

### Loading / vazio

- Loading: spinner no lugar dos tiles (mesmo padrão de [detalhe.md](detalhe.md)).
- Sem linhas: `"Sem contas neste mês."`.

## Edge cases

- **Linha de Contas com `rateio` vazio:** não aparece para ninguém, e o total do card também a ignora — ver [../rules/contas-rows.md](../rules/contas-rows.md). É uma linha mal preenchida na planilha, não um bug da tela.
- **Linha `Metade`:** aparece para Júlio **e** para Dani, com o valor cheio na lista e metade em "sua parte".
- **Editar muda a origem para `Cartão` ou troca o rateio:** a linha some da lista ao recarregar. Esperado — ela saiu do bucket.
- **Mês sem contas:** tiles em `R$ 0,00` e mensagem de vazio.

## Implementações

- **Flutter:** [app/lib/features/contas/contas_page.dart](../../../app/lib/features/contas/contas_page.dart)
- Rota registrada em [app/lib/app.dart](../../../app/lib/app.dart).

## Specs relacionadas

- [../rules/contas-rows.md](../rules/contas-rows.md) — o filtro autoritativo
- [../rules/split-for-person.md](../rules/split-for-person.md) — a divisão por rateio
- [inicio.md](inicio.md) — card de onde se navega
- [detalhe.md](detalhe.md) — tela irmã (Cartão pessoal)
- [../cards/recent-entry-row.md](../cards/recent-entry-row.md) — linha da lista
