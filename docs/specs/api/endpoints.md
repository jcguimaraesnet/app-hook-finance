---
status: stable
last_updated: 2026-05-26
---

# API endpoints

Apps Script único como backend. Frontend (PWA + Flutter) acessa via `/api/proxy` na Azure Function bridge — ver [proxy.md](proxy.md). PWA chama same-origin (relativo); Flutter usa URL absoluta hardcoded para o `<azure-swa>/api/proxy` (ver [proxy.md](proxy.md) — Implementações).

## Contexto

`doGet`/`doPost` em [Dashboard.gs](../../../apps-script/dashboard/Dashboard.gs) despacham por `action`. Webhook (Tasker/IFTTT) reusa o mesmo `doPost` — ver [webhook.md](webhook.md). Todo endpoint exige token (exceto resposta de erro de unknown_action).

## Regras

### Autenticação

- Token único, guardado em `PropertiesService.getScriptProperties().getProperty("WEBHOOK_TOKEN")`.
- Verificado por `checkToken_(token)` em todo endpoint.
- Token é o mesmo do webhook — não há separação entre auth de leitura/escrita/webhook.
- Sem token / token inválido → `{ ok: false, error: "unauthorized" }` (HTTP 200; o erro vem no body).
- `validateToken(candidate)` no PWA testa via `lastEntries(n=1)`.

### GET endpoints (querystring)

| `action` | Params | Resposta | Descrição |
|---|---|---|---|
| `monthData` | `token`, `month?` (`"DD/MM/YYYY"`) | `{ ok, month, rows[] }` | Linhas do mês especificado, ou do mais recente se omitido. Cada linha traz `row` (1-indexed) para edit/delete. |
| `historicalSummary` | `token` | `{ ok, months[], history: { months[], totals[], julioPessoal[], daniPessoal[] } }` | Agregado pré-computado dos últimos 12 meses. |
| `lastEntries` | `token`, `n` (default 10) | `{ ok, entries[] }` | Últimas N linhas inseridas (com `row` 1-indexed para edit/delete). |
| `newInvoicePreview` | `token` | `{ ok, invoiceClosing }` | Read-only: data que `newInvoice` criaria agora (última fatura da planilha + 1 mês), sem inserir nada. Usado pelo dialog de confirmação. Ver [../rules/new-invoice.md](../rules/new-invoice.md). |
| `(none)` ou desconhecido | — | `{ ok: false, error: "unknown_action" }` | Não há landing page; backend é JSON-only. |

### POST endpoints (body JSON, `Content-Type: text/plain` para evitar preflight CORS)

| `body.action` | Body extra | Resposta | Descrição |
|---|---|---|---|
| `addEntry` | `fields: { data?, dataRef?, descricao, valor, origem, categoria?, rateio?, banco?, parcela?, acerto? }` | `{ ok, row }` | Insere uma nova linha no **topo** (row 2) da planilha. `row` na resposta é sempre `2` (1-indexed). Não há dedup. |
| `updateEntry` | `row` (number, 1-indexed), `fields: { descricao, valor, categoria, rateio, parcela, data, dataRef, origem, banco? }` | `{ ok, row }` | Edita colunas A(1), B(2), C(3), D(4), E(5), F(6), G(7), I(9); H(8) só se `banco` vier no body. **Não** edita J. |
| `deleteEntry` | `row` (number) | `{ ok }` | Remove a linha. |
| `newInvoice` | — | `{ ok, invoiceClosing, fixedCount, parcelaCount }` | Cria bloco da próxima fatura. Ver [../rules/new-invoice.md](../rules/new-invoice.md). |
| `ensureHeader` | — | `{ ok, inserted }` | Garante que a linha 1 é o cabeçalho (`SHEET_HEADERS`). Se a linha 1 não começa com `Data`, insere uma linha acima e grava os headers (`inserted: true`); senão só reescreve (`inserted: false`). Idempotente, com `LockService`. Manutenção. |
| `(webhook)` | `title`, `text` | `{ ok }` ou `{ ok: true, deduped: true }` | Caminho legado — ver [webhook.md](webhook.md). |

#### `addEntry` — detalhes

Inserção manual (UI "+ Novo"). Diferente do webhook, não passa por `parsePurchase_` e não classifica via `Classifier`. Bloco de fatura é criado apenas via Nova fatura (ver [../rules/new-invoice.md](../rules/new-invoice.md)); nenhum endpoint o cria automaticamente. O cliente é responsável por enviar todos os campos prontos.

**Campos obrigatórios**:
- `descricao` (string, não-vazia após trim)
- `valor` (number; aceita negativo para estornos/ajustes)
- `origem` (string ∈ `Cartão` \| `Pix (contas)` \| `Pessoal` \| `Empregados` \| `Contas`)

**Campos opcionais** (default em `""`, exceto datas):
- `data` (string `DD/MM/YYYY`) — default: hoje no TZ do script.
- `dataRef` (string `DD/MM/YYYY` ou `DD/MM/YYYY HH:MM`) — default: agora no TZ do script.
- `categoria` (string livre)
- `rateio` (string ∈ `""` \| `Julio` \| `Dani` \| `Metade` \| `Alzira`)
- `banco` (string ∈ `""` \| `Santander` \| `Revolut`) — banco emissor do cartão; só faz sentido com `origem = Cartão`. **Pré-2026-09-12** o campo era `cardLast4` (4 dígitos); `cardLast4` no body agora é ignorado.
- `parcela` (string vazia OU `"X/Y"` onde X,Y são dígitos)
- `acerto` (string vazia OU `"Sim"`)

**Erros**:
- `unauthorized` — token inválido.
- `missing_descricao` / `missing_valor` / `missing_origem` — campo obrigatório vazio/ausente.
- `invalid_valor` — `valor` não é número.
- `invalid_data` — `data` não casa `^\d{2}/\d{2}/\d{4}$` (pós-2026-09-12).
- `invalid_origem` / `invalid_rateio` / `invalid_banco` / `invalid_acerto` — fora do enum.
- `invalid_parcela` — string não vazia que não casa `^\d+\/\d+$`.
- `lock_timeout` — `LockService` não conseguiu lock em 10s.
- `sheet_not_found` — `SHEET_NAME` não existe na planilha.

**Comportamento**:
- Insere no **topo** via `insertRowsBefore(2, 1)` + `setValues`, mantendo a convenção do webhook (linha 2 = mais recente). Sem reorder por data — o cliente que decide se faz sentido inserir no topo um lançamento antigo.
- Col A recebe `parseBrDate_(data)` (Date object) + `setNumberFormat("dd/MM/yyyy")`, igual ao webhook. Até 2026-09-12 gravava a string crua — causa das datas em texto na planilha.
- Força `setNumberFormat("@")` na coluna I (Parcela) antes do `setValue` (mesmo cuidado que `updateEntry`).
- Usa `LockService.getScriptLock()` com timeout 10s (mesmo padrão do webhook) pra serializar inserções concorrentes.

#### `updateEntry` — detalhes

Atualização de uma linha existente. **Pós-2026-05-11** aceita os 8 campos editáveis (todos obrigatórios na request); a versão pré-2026-05-11 aceitava só 5 (descricao/valor/categoria/rateio/parcela) e mantinha A/B/E inalterados.

**Campos obrigatórios** (todos):
- `row` (top-level, não em `fields`): linha 1-indexed.
- `fields.descricao` (string)
- `fields.valor` (number)
- `fields.categoria` (string; pode ser vazia)
- `fields.rateio` (string; pode ser vazia — ver enum em addEntry)
- `fields.parcela` (string vazia OU `"X/Y"`)
- `fields.data` (string `DD/MM/YYYY`, não-vazia)
- `fields.dataRef` (string `DD/MM/YYYY HH:MM`, não-vazia)
- `fields.origem` (string; mesmo enum de `addEntry`)

**Campo opcional** (pós-2026-09-12):
- `fields.banco` (string ∈ `""` \| `Santander` \| `Revolut`). Se **ausente** do body (`undefined`), col H não é tocada — mantém compatibilidade com clientes antigos (APK anterior) que não conhecem o campo. Se presente, é validado e gravado (inclusive `""`, que limpa a célula).

**Erros adicionais** (além de `unauthorized`/`invalid_row`/`row_out_of_range`/`sheet_not_found`):
- `missing_data` / `missing_dataRef` / `missing_origem` — campo vazio ou ausente.
- `invalid_data` — `data` fora de `DD/MM/YYYY` (pós-2026-09-12).
- `invalid_origem` / `invalid_banco` — fora do enum.

**Comportamento**:
- Col A: grava `parseBrDate_(data)` (Date) + `setNumberFormat("dd/MM/yyyy")`. **Até 2026-09-12** forçava `@` e gravava a string — toda linha editada pelo app ficava com a data da fatura em texto. Editar a linha de novo agora converte para Date.
- Força `setNumberFormat("@")` nas colunas B (dataRef) e I (parcela).
- Sem `LockService` — assume baixa concorrência em edição manual (diferente do `addEntry`/webhook).

#### `newInvoice` — detalhes

Gatilho manual da fatura (alternativa ao webhook). Útil quando o iPhone não recebe push de fechamento, ou quando o mês foi sem compras de cartão.

**Sem campos no body** além de `action` e `token`. Backend computa a data de fechamento (`nextInvoiceClosingDate_()`).

**Resposta de sucesso:**
- `invoiceClosing` (string `DD/MM/YYYY`) — data da fatura criada.
- `fixedCount` (number) — quantas despesas fixas foram inseridas (vem da aba `despesas-fixas`).
- `parcelaCount` (number) — quantas parcelas foram roladas da fatura anterior.

**Erros:**
- `unauthorized` — token inválido.
- `lock_timeout` — concorrência (webhook rodando simultaneamente).
- `sheet_not_found` — aba `Despesas` não existe.
- `invoice_already_exists` — fatura `DD/MM/YYYY` já existe na planilha. Resposta inclui `invoiceClosing` para o cliente exibir.
- `fixed_expenses_failed` — aba `despesas-fixas` malformada. Resposta inclui `detail` com a mensagem original.

**Comportamento:**
- Bloco inserido no topo (linha 2) via `buildInvoiceBlock_` + `applyInvoiceBlock_`. Parcelas pendentes da fatura anterior são inseridas **acima** das despesas fixas, com um blank separador entre elas. Linha azul (`#cfe2f3`) marca início da fatura.
- Rollover de parcelas: linhas com col I matching `X/Y` onde `X < Y` viram nova linha com col I = `(X+1)/Y`. Col B (Data Referência) preservada — audit trail. Linhas com parcela malformada (não casa regex, ou `X >= Y`) são puladas silenciosamente.
- `LockService.getScriptLock()` com timeout 10s.

Spec completo: [../rules/new-invoice.md](../rules/new-invoice.md).

### Estrutura de `Row` (resposta de `monthData`)

```json
{
  "row": 137,
  "data": "06/05/2026",
  "dataRef": "03/04/2026 14:32",
  "descricao": "MERCADO ABC",
  "valor": 89.50,
  "origem": "Cartão",
  "categoria": "Alimentação",
  "rateio": "Metade",
  "banco": "Santander",
  "parcela": "",
  "acerto": ""
}
```

> `banco` substituiu `cardLast4` em 2026-09-12. Linhas ainda não migradas podem devolver o valor legado numérico (ex.: `"784"`) nesse campo — clientes devem exibir como está, sem quebrar.

> `row` passou a vir em `monthData` em 2026-09-18 (antes só `lastEntries` tinha). É o índice real da planilha, não a posição no array: `rows[]` já sai filtrado pelo mês e o bloco de "início de fatura" cria buracos. Cliente que não recebe `row` (backend antigo) deve tratar como não-editável, nunca como `0`.

### Estrutura de `Entry` (resposta de `lastEntries`)

Mesma estrutura de `Row`. O campo `row` (1-indexed da planilha) é o que `updateEntry`/`deleteEntry` exigem.

### Estrutura de `historicalSummary.history`

- `months: string[]` — últimos 12 meses **ascendente** (`"DD/MM/YYYY"`).
- `totals: number[]` — total geral por mês, **excluindo** linhas com `origem === "Pessoal"`.
- `julioPessoal: number[]` — soma de `valor` onde `origem === "Cartão"` E `rateio === "Julio"`. Valor cheio (não dividido).
- `daniPessoal: number[]` — soma de `valor` onde `origem === "Cartão"` E `rateio === "Dani"`. Valor cheio.
- Top-level `months` (não `history.months`): **todos** os meses distintos, **descendente** — usado pelo dropdown de filtro do StickyHeader.

## Edge cases

- **Sheet vazia (só headers):** todo endpoint retorna `{ ok: true, ...estrutura vazia... }`. Não erro.
- **`monthData` com `month` que não existe:** retorna `{ ok: true, month: <valor recebido>, rows: [] }`.
- **`monthData` sem `month` E sheet vazia:** retorna `{ ok: true, month: null, rows: [] }`.
- **`updateEntry`/`deleteEntry` com `row < 2`:** `{ ok: false, error: "invalid_row" }`.
- **`updateEntry`/`deleteEntry` com `row > lastRow`:** `{ ok: false, error: "row_out_of_range" }`.
- **`row` obsoleto:** `addEntry`, o webhook e Nova fatura inserem no **topo** e empurram todas as linhas para baixo, então um `row` lido antes da inserção passa a apontar para a linha de cima. Vale igual para `monthData` e `lastEntries`; o backend não tem como detectar. Cliente deve reler a lista depois de qualquer inserção (invalidar os providers) e não guardar `row` entre sessões.
- **`historicalSummary` quando há menos que 12 meses:** retorna o que houver, do mais antigo ao mais recente.
- **Parcela:** `updateEntry` e `addEntry` forçam `setNumberFormat("@")` na célula antes de gravar para impedir Sheets auto-parsear `"1/3"` como data.
- **`addEntry` em sheet vazia (só headers):** insere na linha 2 normalmente; retorna `{ ok: true, row: 2 }`.
- **`addEntry` sem dedup:** o caller pode criar duplicatas. O dedup de 5min do webhook não se aplica.

## Performance

- `Utilities.formatDate` é caro (IPC por chamada). `getMonthData` e `getHistoricalSummary` cacheiam por `Date.getTime()`. Manter esse padrão em qualquer endpoint que itere linhas.
- `historicalSummary` lê só A..G do slab que cobre 12 meses, não a planilha inteira.
- `lastEntries` lê só as primeiras `n` linhas (planilha é descendente por inserção).

## Implementações

- **Backend (autoritativo):** [apps-script/dashboard/Dashboard.gs](../../../apps-script/dashboard/Dashboard.gs)
- **PWA cliente:** [web/src/api/client.ts](../../../web/src/api/client.ts) + [web/src/api/endpoints.ts](../../../web/src/api/endpoints.ts)
- **PWA proxy:** [web/api/proxy/index.js](../../../web/api/) (Azure Function)
- **PWA hooks (cache layer):** `web/src/hooks/useMonthData.ts`, `useHistoricalSummary.ts`, `useLastEntries.ts`
- **Flutter cliente (futuro):** `app/lib/api/client.dart` + `app/lib/api/endpoints.dart`

## Specs relacionadas

- [proxy.md](proxy.md)
- [webhook.md](webhook.md)
- [../data/despesas-sheet.md](../data/despesas-sheet.md)
