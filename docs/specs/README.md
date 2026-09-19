# docs/specs — fonte da verdade

Este diretório guarda as **regras de comportamento** do hook-finance. É a fonte da verdade para o backend (Apps Script), o PWA (`web/`) e o app Flutter (`app/`, futuro).

## Meta-regra

> **Toda mudança de comportamento começa aqui.**
>
> 1. Edite (ou crie) o spec relevante neste diretório.
> 2. Propague a mudança para `web/src/core/` (PWA) e `app/lib/core/` (Flutter, quando existir).
> 3. Ajuste o backend `apps-script/` se a regra for de servidor.
> 4. Componentes/widgets consomem `core/` — **nunca** redefinem regras.
>
> Mudanças puramente visuais (CSS no PWA, layout de widget no Flutter) podem ir direto no código.

## Estrutura

```
docs/specs/
├── README.md                       Este arquivo (índice + meta-regra)
├── _template.md                    Modelo de novo spec
├── conventions.md                  pt-BR, formatação, naming, comentários
├── data/
│   └── despesas-sheet.md           Schema da planilha (cols A-J)
├── api/
│   ├── endpoints.md                REST: GET/POST contracts
│   ├── proxy.md                    /api/proxy (Azure Function bridge)
│   └── webhook.md                  Tasker/IFTTT POST {title, text, token}
├── rules/
│   ├── split-for-person.md         valor que cabe a uma pessoa por linha
│   ├── bucket-key.md               agrupamento Cartão+rateio → label
│   ├── bucket-deltas.md            % vs. mês anterior por bucket (Flutter Início)
│   ├── diff-calculation.md         diff Pix vs Contas+Empregados (PersonCard/AcertoCard)
│   ├── parcela-format.md           "X/Y", parcelaTotal, isParcelado
│   ├── personal-summary.md         4 tiles (total/cartão/parcelado atual+próx) por pessoa
│   ├── contas-rows.md              linhas do bucket Contas de uma pessoa (não-Cartão)
│   ├── classifier.md               Jaccard sobre histórico (categoria/rateio)
│   ├── webhook-parser.md           PURCHASE_RE (Santander) + NEW_APP_VALUE_RE (Revolut)
│   ├── invoice-closing-date.md     próximo fechamento + INVOICE_CLOSING_DAY
│   ├── card-to-person.md           REMOVIDO (col H virou Banco: Santander|Revolut)
│   ├── fixed-expenses.md           insercao automática de despesas mensais fixas
│   └── webhook-dedup.md            janela de 5min via SHA-256
├── cards/
│   ├── person-card.md              Cards de pessoa em Consulta/Pessoal
│   ├── acerto-card.md              Cards de pessoa em Acerto
│   ├── categoria-table.md          Tabela "Cheio | Compart."
│   ├── rateio-chart.md             Bar chart por rateio
│   ├── historico-chart.md          Linha 12 meses (mobile=6)
│   └── recent-entry-row.md         Linha de lançamento (avatar + meta + parcela inline)
├── pages/
│   ├── consulta.md                 PWA: 4 sub-tabs mobile/tablet; sem sub-tabs ≥750px
│   ├── inicio.md                   Flutter (Bloom): visão pessoal + donut + comparativo
│   ├── compart.md                  Flutter (Bloom): cartão compartilhado por categoria
│   ├── historico.md                Flutter (Bloom): 6 meses (total + per-pessoa)
│   ├── detalhe.md                  PWA: accordions; Flutter: drill-down ?person=
│   ├── contas.md                   Flutter: drill-down da coluna Contas do Comparativo
│   ├── lancamento.md               lista + edit modal; Flutter tem tab "+ Novo" stub
│   └── acerto.md                   PWA: 2 cards; Flutter: D/J selector + 1 tabela
├── state/
│   └── persistence.md              persist (localStorage) vs session (sessionStorage)
├── responsive/
│   └── breakpoints.md              640px / 750px (web). Flutter usa MediaQuery.
└── features/
    └── captura-notificacoes.md     Captura de notif. de apps externos (Android, Flutter)
```

## Como ler um spec

Cada arquivo segue o template em [_template.md](_template.md). Seções fixas:

- **Contexto** — por que essa regra/card existe
- **Regras** — lista numerada (autoritativa)
- **Edge cases** — comportamento em situações limítrofes
- **Implementações** — paths para PWA, Flutter, backend
- **Specs relacionadas** — links cruzados

Frontmatter no topo (`status`, `last_updated`) ajuda a identificar specs estáveis vs em rascunho.

## Quando criar um spec novo

Crie um spec quando uma regra:

1. **Vai existir em mais de uma codebase** (ex: cálculo que precisa rodar igual no PWA e no Flutter), ou
2. **Não é evidente pelo nome** da função/componente (uma fórmula sutil, um edge case), ou
3. **Já está duplicada** em vários arquivos da mesma codebase (sintoma).

Não crie spec para: nomes de classes CSS, layout de grid, ordem de imports, ou qualquer coisa puramente cosmética.

## Quando atualizar um spec

**Antes** de mexer no código. Sempre.

Se você só descobriu uma divergência depois (código já mexido, spec desatualizada), atualize o spec ainda assim e cite o commit no campo `last_updated`. Drift documentado é melhor que drift silencioso.
