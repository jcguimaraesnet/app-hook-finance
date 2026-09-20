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
3. **Card hero**: `BloomDonut` à esquerda + bloco com:
   - Kicker "TOTAL PESSOAL" + valor display completo (sem `compact`).
   - Pílula de delta vs. mês anterior (`good`/`bad` cor) sobre `Σ buckets` da pessoa.
   - 3 linhas (1 por bucket) com cor + label + percentual; tap reflete no donut.
   - Link "Ver pessoal →" que navega para `/detalhe?person=<atual>`.
4. **Person pills** (Júlio/Dani) — toggle ativo via fundo `ink`.
5. **Tiles 2-col**: `Total crédito` + `Parcelado` (totais brutos do mês). Rotulado `TOTAL CARTÃO` até a migração de Origem (2026-09-20).
6. **Card "Comparativo vs. <mês anterior>"** com 3 colunas (Compart/Pessoal/Débito), separadas por divisor vertical. Cada coluna: bullet de cor + kicker + valor compact + pílula `↗` (bad) ou `↘` (good) com `prevDelta %`.
   - **Coluna Débito é clicável** (pós-2026-09-19): navega para `/debito?person=<atual>` — ver [debito.md](debito.md). As outras duas não são: Compartilhado já tem a aba Compart e Pessoal já tem o "Ver pessoal →" do hero.
7. **Seção "Últimos lançamentos"**: 2 itens via `lastEntries(2)` + link "Ver mais →" para `/lancamento`.

### Donut interativo

- 3 arcos compart/pessoal/debito com cores `violet`/`mint`/`sky` (escala fixa, não Person-derived).
- Tap em arco → segmento expande (`stroke + 4`), demais ficam 35% opacos. Centro mostra label do bucket + valor + `pct%`.
- Tap fora dos arcos / segundo tap → desselecciona.
- Cálculo dos buckets: ver [bucket-key.md](../rules/bucket-key.md) e [split-for-person.md](../rules/split-for-person.md).

### Person switcher

Selectiona a pessoa cuja visão pessoal é exibida (afeta donut + tiles + comparativo + recentes). Persiste em `selectedPersonProvider` (sessão).

### Cores por pessoa

- **Júlio** → `BloomColors.mint` (menta/verde).
- **Dani** → `BloomColors.violet` (lilás).

Aplicadas via `BloomColors.forPerson(p)` — usadas no avatar do `_PersonTile`, donut central, pill ativa de troca e em qualquer linha de lançamento cujo `rateio` aponte para essa pessoa (ver [../cards/recent-entry-row.md](../cards/recent-entry-row.md)).

**Importante:** cores dos buckets (`Compartilhado=violet`, `Pessoal=mint`, `Débito=sky`) no `_HeroCard` são independentes da pessoa e não trocam.

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
