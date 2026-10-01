---
status: stable
last_updated: 2026-10-01
---

# Início — visão pessoal (Flutter, direção Bloom)

Página default ao logar **no app Flutter** (Bloom IA, 5 abas). Mostra o gasto do mês de uma pessoa selecionada (Júlio ou Dani): donut de duas fatias, os quatro quadrantes de origem × rateio e os últimos lançamentos.

> **Escopo:** apenas Flutter. PWA continua em [consulta.md](consulta.md) (4 sub-tabs).

## Contexto

Substitui as sub-abas `Mês` e `Pessoal` da [Consulta](consulta.md) do PWA, tratando a divisão da fatura como dado primário. O total compartilhado tem visualização separada em [Categoria](compart.md), e o detalhamento de lançamentos pessoais é drill-down para [Despesas pessoais](detalhe.md).

## Regras

### Inputs

- `monthData(currentMonth)` — fatura atual.
- `lastEntries(4)` — para a seção "Últimos lançamentos".
- **Não** usa mais `monthData(previousMonth)`: o comparativo saiu da tela no redesenho de 2026-10-01.

### Layout (top-to-bottom)

Redesenhado em 2026-10-01 a partir do canvas de design "Hook Finance — Tela inicial" (artboard `Proposta`). A tela deixou de ser "saudação + seletor + donut + comparativo + tiles" e virou **um card de pessoa + um card de totais + a lista**.

1. **App-bar custom**: `BloomLogo` (36px) + título "Hook Finance" + **pílula de mês abreviada** ("Nov 2026", `MonthSelector(abbrev: true)`) + **menu hambúrguer** (`☰`, 36px). Items do menu:
   - **Nova fatura** — busca a data via GET `?action=newInvoicePreview` (última fatura da planilha + 1 mês; o cliente não a computa localmente), abre dialog "Criar fatura DD/MM/YYYY? Vai inserir despesas fixas e parcelas pendentes." Confirma → POST `?action=newInvoice` → SnackBar com `$fixedCount fixas + $parcelaCount parcelas`. Durante o preview + criação o item fica `busy`. Ver [../rules/new-invoice.md](../rules/new-invoice.md).
   - **Atualizar** — invalida providers `monthData`, `previousMonthData`, `historicalSummary`, `lastEntries`. SnackBar "Atualizado".
   - **Despesas fixas** — `context.push('/despesas-fixas')`. Edita o template da Nova fatura — ver [despesas-fixas.md](despesas-fixas.md).
   - **Configurações** — `context.push('/settings')`. Mostra também a versão do binário no rodapé (`PackageInfo`, não hardcoded).
   - **Sair** — `signOut()` no auth provider.
   - O título usa `Expanded` **sem** `Spacer` depois: os dois têm flex 1 e dividiriam a sobra, truncando "Hook Fina…" com a pílula já no tamanho final.
   - ~~Saudação "Olá, Júlio"~~ — removida. A pílula de mês, que morava nela, subiu para a app-bar.
2. **Card de pessoa** (branco, raio 28, padding 8):
   1. **Seletor de pessoa em trilho único** (segmented control): trilho `track`, raio 22, duas abas de 44px; a marcada é branca com elevação (`surfaceTintColor: transparent`, senão o M3 a deixa mais escura que a não-marcada), avatar quadrado de 24px na cor da pessoa. **Sem valores** — o total agora é um só, logo abaixo, e é o da pessoa marcada. Substituiu dois tiles que repetiam o total de cada um.
   2. **"Gastos de &lt;pessoa&gt; no mês"** + valor display 32px (prefixo `R$` em 17px) à esquerda; **donut de 92px** à direita, sem texto no centro (o nome já está no título).
   3. **Legenda** de duas linhas abaixo do valor: bullet + rótulo + percentual. Tocar numa linha ou num arco destaca a fatia e apaga a outra.
   4. ~~Atalho "Crédito (pessoal)"~~ — **removido**. O canvas o desenhava logo abaixo do donut, repetindo o valor do quadrante `Crédito pessoal` a poucos pixels de distância; o quadrante leva ao mesmo `/detalhe`.
3. **Card de totais**:
   1. **2×2 de quadrantes** da pessoa marcada: `Crédito compartilhado` · `Débito compartilhado` · `Crédito pessoal` · `Débito pessoal`. Vêm de `PersonBuckets` e **somam exatamente o total do card de pessoa** — teste trava a partição. Compartilhado em tint lilás, pessoal em tint menta.
   2. Linha larga **"Total cartão de crédito"**, **abaixo** dos quatro (o canvas a punha acima) — `origemTotals(rows).credito`, ou seja o crédito do **casal**, não o da pessoa. Ver [origem-totals.md](../rules/origem-totals.md).
   3. Os quatro quadrantes são clicáveis (os dois de cima → aba [Categoria](compart.md) com a origem marcada; os dois de baixo → `/detalhe`). O design os desenha estáticos; manter o toque preserva a navegação que existia no card Comparação, sem mudar nada visualmente.
4. **Seção "Últimos lançamentos"**: título 17px + link **"Ver todos →"**; card raio 24 com **4** itens (`lastEntries(4)`) na variante larga de [RecentEntryRow](../cards/recent-entry-row.md) — avatar sólido de 40px, descrição 14,5px e a data **dentro** da meta (`Casa · 29/09`). **Tap edita** no mesmo `EditDialog` das outras listas; ao salvar invalida `monthData`, `previousMonthData`, `historicalSummary` e `lastEntries`.
5. **Bottom-nav** de 5 abas — vem do shell, não mudou.

### O que saiu no redesenho

- **Card "Comparação vs. mês anterior"** e com ele **todo o Δ%** da tela. `BucketDeltas`/`bucketDeltas` foram removidos de `bucket_deltas.dart` por ficarem sem consumer; `previousMonthOf` e `PersonBuckets` seguem. Nenhuma outra tela mostrava Δ.
- **Tiles `Total Crédito` + `Total Débito`** (de poucas horas antes): o crédito do casal virou a linha larga do card de totais; o débito do casal não aparece mais — o que a tela mostra de débito agora é o da pessoa, nos dois quadrantes.
- **Saudação** e o **nome no centro do donut**.

### Desvios conscientes do canvas

O canvas propõe tokens que mudariam o app inteiro, não só esta tela. Mantidos os do app, por consistência com as outras 4 abas:

| Canvas | App (mantido) |
|---|---|
| Plus Jakarta Sans + IBM Plex Mono | Bricolage Grotesque + Inter + JetBrains Mono |
| Dani em laranja `#E8956F`, Júlio em `ink` | Dani `violet`, Júlio `mint` ([../rules/split-for-person.md](../rules/split-for-person.md) e todas as listas usam essas cores) |
| Fundo chapado `#F5F4FA` | `screenGradient` do shell |

Adotados do canvas: a estrutura inteira, os raios (28/24/22/20), os chips de ícone circulares, os tints `violetTint`/`mintTint`, o trilho `track` e a linha `soft`.

### Donut interativo

- 2 arcos compartilhado/pessoal com cores `violet`/`mint` (escala fixa, não Person-derived). 92px, stroke 13, **sem texto no centro** (`person: ''`). As cores vão do `_HeroCard` para o `BloomDonut` pelo parâmetro `colors` — **uma lista só** para arco e legenda. Até 2026-10-01 o donut tinha a lista fixa por dentro, na ordem antiga, e reordenar as fatias pintou Pessoal de azul e Débito de verde.
- Tap em arco → segmento expande (`stroke + 4`), demais ficam 35% opacos. Centro mostra label do bucket + valor + `pct%`.
- Tap fora dos arcos / segundo tap → desselecciona.
- Cálculo dos buckets: ver [bucket-key.md](../rules/bucket-key.md) e [split-for-person.md](../rules/split-for-person.md).

### Person switcher

Selectiona a pessoa cuja visão pessoal é exibida (afeta donut + tiles + comparativo + recentes). Persiste em `selectedPersonProvider` (sessão).

### Cores por pessoa

- **Júlio** → `BloomColors.mint` (menta/verde).
- **Dani** → `BloomColors.violet` (lilás).

Aplicadas via `BloomColors.forPerson(p)` — usadas no avatar do seletor de pessoa, pill ativa de troca e em qualquer linha de lançamento cujo `rateio` aponte para essa pessoa (ver [../cards/recent-entry-row.md](../cards/recent-entry-row.md)).

**Importante:** cores dos agrupamentos (`Compartilhado=violet`, `Pessoal=mint`) no `_HeroCard` são independentes da pessoa e não trocam.

## Edge cases

- **Mês sem rows:** todos os buckets em 0; donut renderiza como ring vazio sem segmentos; o valor grande e os quatro quadrantes mostram `R$ 0,00`.
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
