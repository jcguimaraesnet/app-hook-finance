---
status: stable
last_updated: 2026-10-01
---

# Início — visão pessoal (Flutter, direção Bloom)

Página default ao logar **no app Flutter** (Bloom IA, 5 abas). Mostra a despesa pessoal de uma pessoa selecionada (Júlio ou Dani) com donut interativo, comparativo vs. mês anterior e últimos lançamentos.

> **Escopo:** apenas Flutter. PWA continua em [consulta.md](consulta.md) (4 sub-tabs).

## Contexto

Substitui as sub-abas `Mês` e `Pessoal` da [Consulta](consulta.md) do PWA, tratando a divisão da fatura como dado primário (donut + 3 buckets compart/pessoal/debito). O total compartilhado tem visualização separada em [Compart](compart.md), e o detalhamento de lançamentos pessoais é drill-down via tap no donut → [Detalhe pessoal](detalhe.md).

## Regras

### Inputs

- `monthData(currentMonth)` — fatura atual.
- `monthData(previousMonth)` — derivado de `currentMonth` para o card comparativo (ver [bucket-deltas.md](../rules/bucket-deltas.md)).
- `lastEntries(3)` — para a seção "Últimos lançamentos".

### Layout (top-to-bottom)

1. **App-bar custom** com `BloomLogo` + label "hook" à esquerda, **menu hambúrguer** (`☰`) à direita. Items:
   - **Nova fatura** — busca a data via GET `?action=newInvoicePreview` (última fatura da planilha + 1 mês; o cliente não a computa localmente), abre dialog "Criar fatura DD/MM/YYYY? Vai inserir despesas fixas e parcelas pendentes." Confirma → POST `?action=newInvoice` → SnackBar com `$fixedCount fixas + $parcelaCount parcelas`. Durante o preview + criação o item fica `busy`. Ver [../rules/new-invoice.md](../rules/new-invoice.md).
   - **Atualizar** — invalida providers `monthData`, `previousMonthData`, `historicalSummary`, `lastEntries`. SnackBar "Atualizado".
   - **Despesas fixas** — `context.push('/despesas-fixas')`. Edita o template da Nova fatura — ver [despesas-fixas.md](despesas-fixas.md). Pós-2026-09-20.
   - **Configurações** — `context.push('/settings')`. Mostra também a versão do binário no rodapé (`PackageInfo`, não hardcoded).
   - **Sair** — `signOut()` no auth provider.
2. **Saudação** "Olá, Júlio" + título display "Junho, 2026" + `MonthSelector` à direita.
3. **Person pills** (Júlio/Dani) — toggle ativo via fundo `ink`. **Acima do card hero** desde 2026-10-01: é o seletor que define de quem são os números do card logo abaixo.
4. **Card hero**: `BloomDonut` à esquerda + 2 linhas (1 por agrupamento) com cor + label + percentual; tap destaca o arco e apaga o outro.
   - Agrupamentos: **Compartilhado · Pessoal** (pós-2026-10-01). A mesma ordem do card Comparação. Regras em [bucket-deltas.md](../rules/bucket-deltas.md).
     - `Compartilhado` = `credito + debito` do `PersonBuckets` — tudo que é rateado `Compartilhado`, **nas duas origens**, pela metade da pessoa.
     - `Pessoal` = rateio da pessoa, em qualquer origem.
     - Passou por **Crédito · Débito · Pessoal** mais cedo em 2026-10-01; o corte por origem saiu do donut e virou os dois tiles do item 6.1.
   - **Sem o bloco "TOTAL PESSOAL" + valor** (pós-2026-10-01): o hero virou visão de proporção. Os valores absolutos estão nos tiles abaixo e no Comparativo. Efeito colateral aceito: tocar numa fatia já não mostra o valor dela — o retorno é visual (arco + dim).
   - Labels e percentuais em 14,5px (eram 11,5).
   - ~~Link "Ver pessoal →"~~ e ~~chips "Ver pessoal"/"Ver compartilhado"~~ — **removidos em 2026-10-01**. Nenhuma navegação se perdeu: as duas colunas do Comparação abrem `/detalhe` e a aba Categoria.
5. ~~**Tiles 2-col** `Total crédito` + `Parcelado`~~ — **removidos em 2026-10-01**. O parcelado saiu da Início de vez; o total de crédito voltou no item 6.1, agora somando as duas pessoas.
6. **Card "Comparação vs. <mês anterior>"** com 2 colunas (Compartilhado/Pessoal, mesma ordem do hero), separadas por divisor vertical. Sem o link "Ver histórico →" desde 2026-10-01 — a aba Histórico está na barra inferior. Cada coluna: bullet de cor + kicker + valor compact + pílula `↗` (bad) ou `↘` (good) com `prevDelta %`.
   - O Δ de `Compartilhado` é calculado **sobre a soma** (crédito + débito), não pela média dos dois Δ: a média de dois percentuais não é o percentual da soma, e um dos dois pode ser `null`.
   - **As duas colunas são clicáveis**:
     - **Compartilhado** → aba Categoria (antes rotulada "Compart") **sem filtro de origem marcado**. O `COMPARTILHADO / 2` de lá passa a ser `Σ valor/2` de todas as linhas `Compartilhado` — a mesma conta desta coluna, então os dois fecham. Marcar uma origem mostraria só um pedaço do número clicado.
     - **Pessoal** → `/detalhe?person=<atual>`. O tile "TOTAL PESSOAL" de lá é `Σ valor` onde `rateio == pessoa`, idêntico à coluna. ⚠️ A **lista** daquela tela é só de Crédito, então ela mostra um subconjunto do próprio tile — pendência anterior à mudança.
     - Até mais cedo em 2026-10-01 eram três colunas, e **Crédito**/**Débito** levavam à aba Categoria com o tile de origem correspondente marcado. Esse fluxo continua existindo pelos tiles da própria aba Categoria; a tela `/debito` segue removida.
6.1. **Tiles `Total Crédito` + `Total Débito`**, logo **abaixo** do card Comparação (pós-2026-10-01). Mesma casca dos tiles de pessoa do item 3 (widget `_SummaryTile`, 2 colunas, avatar circular 32px): Crédito com `credit_card` em `violet`, Débito com `account_balance_outlined` em `sky`. Não são clicáveis nem selecionáveis — a navegação por origem já está no Comparação logo acima.
   - Regra: [origem-totals.md](../rules/origem-totals.md). Somam `splitForPerson` das **duas** pessoas, então `Crédito + Débito` é exatamente `Júlio + Dani` dos tiles do item 3 (teste trava isso). Linhas de terceiro (`Alzira`) ou sem rateio ficam fora, como no resto da tela.
   - ⚠️ Não confundir com o tile `TOTAL CRÉDITO` da aba [Categoria](compart.md), que é o total **da tabela daquela tela** (só `Compartilhado`, recortado pelo filtro de origem) e por isso dá outro número.
7. **Seção "Últimos lançamentos"**: 3 itens via `lastEntries(3)` (2 até 2026-10-01, depois 4, depois 3 no mesmo dia) + link "Ver mais →" para `/lancamento`. **Tap edita** o lançamento no mesmo `EditDialog` das outras listas (pós-2026-10-01); ao salvar invalida `monthData`, `previousMonthData`, `historicalSummary` e `lastEntries`.

### Donut interativo

- 2 arcos compartilhado/pessoal com cores `violet`/`mint` (escala fixa, não Person-derived). `sky` saiu do hero junto com a fatia de Débito, mas segue no tile `Total Débito` do item 6.1. As cores vão do `_HeroCard` para o `BloomDonut` pelo parâmetro `colors` — **uma lista só** para arco e legenda. Até 2026-10-01 o donut tinha a lista fixa por dentro, na ordem antiga, e reordenar as fatias pintou Pessoal de azul e Débito de verde.
- Tap em arco → segmento expande (`stroke + 4`), demais ficam 35% opacos. Centro mostra label do bucket + valor + `pct%`.
- Tap fora dos arcos / segundo tap → desselecciona.
- Cálculo dos buckets: ver [bucket-key.md](../rules/bucket-key.md) e [split-for-person.md](../rules/split-for-person.md).

### Person switcher

Selectiona a pessoa cuja visão pessoal é exibida (afeta donut + tiles + comparativo + recentes). Persiste em `selectedPersonProvider` (sessão).

### Cores por pessoa

- **Júlio** → `BloomColors.mint` (menta/verde).
- **Dani** → `BloomColors.violet` (lilás).

Aplicadas via `BloomColors.forPerson(p)` — usadas no avatar do `_PersonTile` (hoje uma casca sobre `_SummaryTile`), donut central, pill ativa de troca e em qualquer linha de lançamento cujo `rateio` aponte para essa pessoa (ver [../cards/recent-entry-row.md](../cards/recent-entry-row.md)).

**Importante:** cores dos agrupamentos (`Compartilhado=violet`, `Pessoal=mint`) no `_HeroCard` são independentes da pessoa e não trocam. `sky` segue reservado a Débito nos tiles do item 6.1.

## Edge cases

- **Mês sem rows:** todos os buckets em 0; donut renderiza como ring vazio sem segmentos. Comparação mostra deltas `—`, e os dois tiles do item 6.1 mostram `R$ 0,00`.
- **Sem mês anterior** (primeiro mês de dados): card comparativo oculta as pílulas de delta, mostra apenas valores absolutos.
- **`lastEntries` vazio:** seção "Últimos lançamentos" mostra mensagem `"Sem lançamentos."`.

## Implementações

- **Flutter:** [app/lib/features/inicio/inicio_page.dart](../../../app/lib/features/inicio/inicio_page.dart)
- **Widgets:** `BloomDonut`, `PersonPill`, `RecentEntryRow` em `app/lib/widgets/bloom/`.
- **PWA:** sem equivalente — usa [consulta.md](consulta.md) (4 sub-tabs).

## Specs relacionadas

- [bucket-deltas.md](../rules/bucket-deltas.md) — cálculo de % vs. mês anterior
- [bucket-key.md](../rules/bucket-key.md) — agrupamento Crédito+rateio
- [split-for-person.md](../rules/split-for-person.md) — alocação por pessoa
- [detalhe.md](detalhe.md) — drill-down do donut
- [compart.md](compart.md) — visão complementar (categoria)
