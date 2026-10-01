---
status: stable
last_updated: 2026-09-20
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
- `lastEntries(2)` — para a seção "Últimos lançamentos".

### Layout (top-to-bottom)

1. **App-bar custom** com `BloomLogo` + label "hook" à esquerda, **menu hambúrguer** (`☰`) à direita. Items:
   - **Nova fatura** — busca a data via GET `?action=newInvoicePreview` (última fatura da planilha + 1 mês; o cliente não a computa localmente), abre dialog "Criar fatura DD/MM/YYYY? Vai inserir despesas fixas e parcelas pendentes." Confirma → POST `?action=newInvoice` → SnackBar com `$fixedCount fixas + $parcelaCount parcelas`. Durante o preview + criação o item fica `busy`. Ver [../rules/new-invoice.md](../rules/new-invoice.md).
   - **Atualizar** — invalida providers `monthData`, `previousMonthData`, `historicalSummary`, `lastEntries`. SnackBar "Atualizado".
   - **Despesas fixas** — `context.push('/despesas-fixas')`. Edita o template da Nova fatura — ver [despesas-fixas.md](despesas-fixas.md). Pós-2026-09-20.
   - **Configurações** — `context.push('/settings')`. Mostra também a versão do binário no rodapé (`PackageInfo`, não hardcoded).
   - **Sair** — `signOut()` no auth provider.
2. **Saudação** "Olá, Júlio" + título display "Junho, 2026" + `MonthSelector` à direita.
3. **Person pills** (Júlio/Dani) — toggle ativo via fundo `ink`. **Acima do card hero** desde 2026-10-01: é o seletor que define de quem são os números do card logo abaixo.
4. **Card hero**: `BloomDonut` à esquerda + 3 linhas (1 por bucket) com cor + label + percentual; tap destaca o arco e apaga os outros.
   - Ordem das fatias: **Crédito · Débito · Pessoal** (pós-2026-10-01). A mesma do card Comparativo. Regras em [bucket-deltas.md](../rules/bucket-deltas.md).
   - **Sem o bloco "TOTAL PESSOAL" + valor** (pós-2026-10-01): o hero virou visão de proporção. Os valores absolutos estão nos tiles abaixo e no Comparativo. Efeito colateral aceito: tocar numa fatia já não mostra o valor dela — o retorno é visual (arco + dim).
   - Labels e percentuais em 14,5px (eram 11,5).
   - ~~Link "Ver pessoal →"~~ e ~~chips "Ver pessoal"/"Ver compartilhado"~~ — **removidos em 2026-10-01**. Nenhuma navegação se perdeu: a coluna **Pessoal** do Comparativo abre `/detalhe` e a **Crédito** abre a aba Categoria.
5. ~~**Tiles 2-col** `Total crédito` + `Parcelado`~~ — **removidos em 2026-10-01**. O total de crédito está na aba [Categoria](compart.md); o parcelado saiu da Início junto.
6. **Card "Comparativo vs. <mês anterior>"** com 3 colunas (Crédito/Débito/Pessoal, mesma ordem do hero). Sem o link "Ver histórico →" desde 2026-10-01 — a aba Histórico está na barra inferior, separadas por divisor vertical. Cada coluna: bullet de cor + kicker + valor compact + pílula `↗` (bad) ou `↘` (good) com `prevDelta %`.
   - **As três colunas são clicáveis** (pós-2026-10-01):
     - **Crédito** → aba Categoria (antes rotulada "Compart"). O "Total compartilhado" de lá é `Σ valor/2` das linhas Crédito+Metade — a mesma conta da fatia, então os dois fecham (conferido: R$ 1.101,47 nas duas telas em 06/11/2026).
     - **Pessoal** → `/detalhe?person=<atual>`. O tile "TOTAL PESSOAL" de lá é `Σ valor` onde `rateio == pessoa`, idêntico à fatia. ⚠️ A **lista** daquela tela é só de Crédito, então ela mostra um subconjunto do próprio tile — pendência anterior à mudança.
     - **Débito** → `/debito?person=<atual>`. ⚠️ A tela lista todo o débito da pessoa, enquanto a fatia conta só `Metade` — ver [../rules/bucket-deltas.md](../rules/bucket-deltas.md).
7. **Seção "Últimos lançamentos"**: 4 itens via `lastEntries(4)` (eram 2 até 2026-10-01) + link "Ver mais →" para `/lancamento`. **Tap edita** o lançamento no mesmo `EditDialog` das outras listas (pós-2026-10-01); ao salvar invalida `monthData`, `previousMonthData`, `historicalSummary` e `lastEntries`.

### Donut interativo

- 3 arcos credito/debito/pessoal com cores `violet`/`sky`/`mint` (escala fixa, não Person-derived). As cores vão do `_HeroCard` para o `BloomDonut` pelo parâmetro `colors` — **uma lista só** para arco e legenda. Até 2026-10-01 o donut tinha a lista fixa por dentro, na ordem antiga, e reordenar as fatias pintou Pessoal de azul e Débito de verde.
- Tap em arco → segmento expande (`stroke + 4`), demais ficam 35% opacos. Centro mostra label do bucket + valor + `pct%`.
- Tap fora dos arcos / segundo tap → desselecciona.
- Cálculo dos buckets: ver [bucket-key.md](../rules/bucket-key.md) e [split-for-person.md](../rules/split-for-person.md).

### Person switcher

Selectiona a pessoa cuja visão pessoal é exibida (afeta donut + tiles + comparativo + recentes). Persiste em `selectedPersonProvider` (sessão).

### Cores por pessoa

- **Júlio** → `BloomColors.mint` (menta/verde).
- **Dani** → `BloomColors.violet` (lilás).

Aplicadas via `BloomColors.forPerson(p)` — usadas no avatar do `_PersonTile`, donut central, pill ativa de troca e em qualquer linha de lançamento cujo `rateio` aponte para essa pessoa (ver [../cards/recent-entry-row.md](../cards/recent-entry-row.md)).

**Importante:** cores dos buckets (`Crédito=violet`, `Pessoal=mint`, `Débito=sky`) no `_HeroCard` são independentes da pessoa e não trocam.

## Edge cases

- **Mês sem rows:** todos os buckets em 0; donut renderiza como ring vazio sem segmentos. Comparativo mostra deltas `—`.
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
