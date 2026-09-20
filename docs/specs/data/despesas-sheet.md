---
status: stable
last_updated: 2026-09-12
---

# Despesas — schema da planilha

Planilha única, aba `Despesas`. Todas as codebases (PWA, Flutter, backend) consomem esse mesmo modelo. Linhas novas são inseridas no **topo** (linha 2 = mais recente).

## Contexto

A planilha é o único banco de dados. Nenhum estado vive fora dela (exceto cache transitório do CacheService para dedup do webhook). Schema estável desde o início; mudanças aqui exigem migração da planilha **antes** de mexer no código.

## Regras

### Colunas (10 total)

| # | Letra | Header | Tipo | Notas |
|---|-------|--------|------|-------|
| 1 | A | Data | Date (formato `dd/MM/yyyy`) | Fechamento da fatura. Webhook usa `latestInvoiceClosingInSheet_(sheet)` (mais recente já registrada). Nova fatura usa `newInvoiceClosingDate_()`. **Todo** write do backend (webhook, Nova fatura, `addEntry`, `updateEntry`) grava `Date` object + `setNumberFormat("dd/MM/yyyy")`. Até 2026-09-12 `addEntry`/`updateEntry` gravavam string (e `updateEntry` forçava `@`) — origem das datas em texto que apareciam na planilha após editar/criar pelo app. Reads usam `formatBrDate_` que aceita Date OU string (compatível com linhas legadas). |
| 2 | B | Data Referência | string `DD/MM/YYYY HH:MM` | Data+hora real da compra (extraída do texto da notificação). |
| 3 | C | Descrição | string | Estabelecimento. Extraído via `PURCHASE_RE` (Santander) ou do `title` (Revolut). |
| 4 | D | Valor | number | Numérico, com 2 casas. Pode ser negativo (estornos, ajustes). |
| 5 | E | Origem | string enum | `Crédito` \| `Débito`. Webhook **sempre** escreve `Crédito` (constante `ORIGEM`). **Pré-2026-09-20** o enum tinha 5 valores (`Cartão`, `Pix (contas)`, `Pessoal`, `Empregados`, `Contas`) — ver "Migração de Origem" abaixo. |
| 6 | F | Categoria | string | Texto livre. Sugerido por `Classifier` (Jaccard). Comuns: `Alimentação`, `Pessoal`, `Contas`, `Saúde`. |
| 7 | G | Rateio | string | `Julio` \| `Dani` \| `Metade` \| `Alzira` \| `""`. Vazio = não rateado. |
| 8 | H | Banco | string enum | `Santander` \| `Revolut` \| `""`. Banco emissor do cartão. Webhook preenche pelo padrão da notificação; `addEntry`/`updateEntry` recebem `banco`. Só faz sentido com Origem `Cartão`; demais origens ficam `""`. **Pré-2026-09-12** guardava os 4 dígitos finais do cartão (`1018`, `2236`, `784`…). Só a fatura 06/10/2026 foi convertida; faturas fechadas mantêm os dígitos por decisão do usuário. |
| 9 | I | Parcela | string | `"X/Y"` (ex.: `"1/3"` = 1ª de 3). Vazio = à vista. Editável só via modal de Lançamento. Ver [parcela-format.md](../rules/parcela-format.md). |
| 10 | J | Acerto | string | `"Sim"` se a linha conta para o "Acerto Final". Vazio caso contrário. |

### Migração de Origem (2026-09-20)

A col E passou de 5 valores para 2. Mapa aplicado:

| Antes | Depois | Linhas migradas |
|---|---|---|
| `Cartão` | `Crédito` | 1.678 |
| `Pix (contas)` | `Débito` | 116 |
| `Contas` | `Débito` | 109 |
| `Empregados` | `Débito` | 30 |
| `Pessoal` | `Débito` | 0 (valor nunca usado na planilha) |

**A migração é irreversível sem backup**: `Pix (contas)`, `Contas` e `Empregados` colapsam no mesmo valor e a distinção some. Nenhuma regra depende mais dela — ver [../rules/diff-calculation.md](../rules/diff-calculation.md), onde isso é demonstrado — mas um backup `row → origem` das 1.933 linhas foi gerado antes de rodar.

Migrada também a col D da aba `despesas-fixas` ([despesas-fixas-sheet.md](despesas-fixas-sheet.md)); sem isso a Nova fatura voltaria a inserir `Pix (contas)`.

Rotina: `migrateOrigemToCreditoDebito()` em `apps-script/shared/Maintenance.gs`, idempotente, rodada manualmente pelo editor.

**Compatibilidade:** `addEntry`/`updateEntry` normalizam valores legados no write (APK antigo manda `Cartão` e o backend grava `Crédito`), e o app normaliza na leitura. As duas pontes são temporárias — ver [../api/endpoints.md](../api/endpoints.md).

### Leitura

- Linha 1 = headers; ignorar ao processar dados.
- Tipos de retorno do backend (`mapRow_`) são todos string exceto `valor` que é number — ver [api/endpoints.md](../api/endpoints.md).
- Para `Parcela` ler `String(r[8] || "").trim()` (formato preservado como texto).
- Para `Acerto` ler `String(r[9] || "")`.

### Inserção

- Webhook insere no **topo** (`insertRowsBefore(2, n)`), não no fim.
- Bloco de "início de fatura" (despesas fixas + linha azul + rollover de parcelas) é criado **apenas** pelo gatilho manual Nova fatura — ver [../rules/new-invoice.md](../rules/new-invoice.md). Webhook não cria mais bloco; só grava a compra na última fatura existente.
- Coluna A (Data) é Date object em todos os writes. Force `setNumberFormat("dd/MM/yyyy")` após inserção pra sobrescrever `@` herdado de linhas vizinhas editadas antes de 2026-09-12.
- Linha 1 é o cabeçalho (`SHEET_HEADERS`). Se sumir, `POST { action: "ensureHeader" }` insere uma linha acima do que estiver na linha 1 e grava os headers — ver [../api/endpoints.md](../api/endpoints.md).
- O write em coluna `I (Parcela)` deve forçar `setNumberFormat("@")` antes do `setValue` para impedir o Sheets de auto-parsear `"1/3"` como data.

## Edge cases

- **Linha sem data** (col A vazia): aparece em blocos brancos do "Início de fatura" (criados por Nova fatura). Backend filtra em todos os endpoints de leitura — `getMonthData`/`getHistoricalSummary` via `if (!d) continue`, `getLastEntries` via skip explícito de linhas onde col A E descrição estão vazias. Frontend (Flutter) também filtra defensivamente em `MonthDataResponse.fromJson` e `LastEntriesResponse.fromJson`.
- **Valor negativo:** legítimo (ajustes/estornos como `Ajuda de custo`). Não filtrar.
- **Rateio em branco + Origem Cartão:** linha aparece em `RateioChart` como `"(sem rateio)"`. Não bate com nenhuma regra de splitForPerson, então não aparece nos PersonCard.
- **`Banco` (col H) vazio:** não usado por nenhuma regra de cálculo; só informativo/filtro. Linhas de Origem `Cartão` anteriores ao webhook ou inseridas sem escolher banco ficam vazias.
- **`Banco` (col H) com valor legado numérico (`784`, `2236`…):** esperado em faturas até 06/09/2026 (não migradas). O modal de edição mostra o valor cru como `(?) 784`; salvar com um banco escolhido corrige a linha.
- **Sheet vazia (só headers):** backend retorna `{ ok: true, rows: [] }`.

## Implementações

- **Backend (autoritativo):**
  - [apps-script/dashboard/Dashboard.gs:294-307](../../../apps-script/dashboard/Dashboard.gs) — `mapRow_(r)` define o contrato linha → JSON.
  - [apps-script/shared/Constants.gs](../../../apps-script/shared/Constants.gs) — `SHEET_ID`, `SHEET_NAME`, `INVOICE_CLOSING_DAY`, `ORIGEM`, `BANCOS`.
  - [apps-script/dashboard/Dashboard.gs](../../../apps-script/dashboard/Dashboard.gs) — `SHEET_HEADERS` + `ensureHeader` (restaura a linha 1).
- **PWA tipos:** `web/src/core/types.ts` (após Onda 2; hoje em `web/src/api/types.ts`).
- **Flutter tipos:** `app/lib/core/types.dart` (após Onda 4).

## Specs relacionadas

- [../api/endpoints.md](../api/endpoints.md) — formato de leitura via REST
- [../rules/parcela-format.md](../rules/parcela-format.md) — interpretação de `"X/Y"`
- [../rules/webhook-parser.md](../rules/webhook-parser.md) — como o webhook decide o `Banco` (col H)
- [../rules/fixed-expenses.md](../rules/fixed-expenses.md) — inserção automática
