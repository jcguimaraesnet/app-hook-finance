---
status: stable
last_updated: 2026-08-01
---

# Nova fatura — gatilho manual + rollover de parcelas

Endpoint manual que cria o bloco "início de fatura" sem depender do webhook. Insere despesas fixas + rola parcelas pendentes da fatura anterior para a nova.

## Contexto

O bloco visual de fatura (linha azul + despesas fixas) é criado **apenas** por este gatilho manual. O webhook já não o cria: ele usa sempre a última fatura registrada na planilha (ver comentário em `Webhook.gs` e [fixed-expenses.md](fixed-expenses.md)). Este spec afirmava o contrário até 2026-09-20 — drift corrigido ao implementar o decremento de parcelas, que depende de existir um caminho único.

A opção de menu "Nova fatura" no app Flutter (aba Início, hamburger menu) chama `?action=newInvoice` (POST) que faz o mesmo trabalho do webhook **e** propaga parcelas pendentes da fatura anterior para a nova com `(X+1)/Y`.

A data que será criada é a **fatura seguinte à última já registrada na planilha** (última col A + 1 mês, ver [invoice-closing-date.md](invoice-closing-date.md)) — não uma projeção a partir de hoje. Como isso depende do estado da planilha, o dialog de confirmação busca a data no backend antes de exibir, via o endpoint read-only `newInvoicePreview` (GET).

## Regras

### Trigger

POST `body.action === "newInvoice"`. Body: `{ "action": "newInvoice", "token": "..." }`. Sem outros campos.

### Algoritmo

1. `checkToken_(token)` → 401 se inválido.
2. `LockService.getScriptLock().tryLock(10000)` — serializa com webhook + addEntry. Se falhar → `lock_timeout`.
3. Abrir aba `Despesas`. Se faltar → `sheet_not_found`.
4. `newClosing = newInvoiceClosingDate_(sheet)` — **última fatura da planilha + 1 mês** (ver [invoice-closing-date.md](invoice-closing-date.md)). Ex.: última fatura registrada = `06/07/2026` → `newClosing = 06/08/2026`, independente da data de hoje. Calculado **dentro do lock**, após abrir a aba, pra ler estado consistente.
5. **Dedup:** se qualquer linha tem `formatBrDate_(col A) === newClosing` → `invoice_already_exists` (preserva idempotência semântica).
6. **Rollover de parcelas:** `findCurrentInvoice_(sheet, newClosing)` retorna `{ closing, rows }` da fatura mais recente STRICTLY LESS THAN `newClosing`, ou `null`. Para cada `r` em `rows`: `rolloverParcelaRow_(r.values, newClosing)` retorna nova linha 10-col ou `null` (skip). Linhas que rolam têm col A = `newClosing`, col I = `(X+1)/Y`, col B (data referência original) preservada. Demais colunas idênticas.
7. **Build bloco:** `buildInvoiceBlock_(newClosing, parcelaRows)` monta `[blank, ...parcelaRows, ...fixedRows, blank, blank, blank]` (parcelas **acima** das fixas — entradas dinâmicas têm prioridade visual). Chama `loadFixedExpenses_()` internamente; se essa lança (aba `despesas-fixas` malformada) → `fixed_expenses_failed` com detail.
8. **Apply:** `applyInvoiceBlock_(sheet, block)` faz `insertRowsBefore(2, N)`, força `setNumberFormat("@")` na col I do bloco inteiro, escreve valores, pinta linha azul (`#cfe2f3`) na penúltima.
8b. **Decremento das despesas fixas finitas:** `decrementFixedParcelas_` baixa em 1 a col H da aba `despesas-fixas` e remove as que zeraram. Roda **depois** do apply — ver [fixed-expenses.md](fixed-expenses.md). Reflete em `fixedDecremented` / `fixedRemoved` na resposta.
9. Lock release no `finally`.
10. Retorna `{ ok: true, invoiceClosing, fixedCount, parcelaCount }`.

### Layout do bloco inserido

Com parcelas roladas:

```
[blank]
[parcela 1]   ← (rolagem da fatura anterior, col I = "X+1/Y")
...
[parcela M]
[blank]       ← separador entre parcelas e despesas fixas
[despesa fixa 1]
...
[despesa fixa N]
[blank]
[blank] ← pintada de azul (#cfe2f3)
[blank]
```

Sem parcelas (primeira fatura sem precedente): o separador some, e o layout vira `[blank, ...fixedRows, blank, blank, blank]`.

### Rollover — regras de matching de parcela

Helper `rolloverParcelaRow_(rowValues, newClosing)`:

- Lê col I (`rowValues[8]`) como string + trim.
- Regex `^\d+\/\d+$` (numérico/numérico).
- Captures `X` e `Y` via `parseInt`.
- **Skip** (retorna `null`) se: regex não bate, OU col I vazia, OU `X >= Y` (parcela final ou inválida).
- Caso contrário: retorna array 10-col com `[newClosing, ...col B..H original..., (X+1)/Y, col J original]`.

## Erros

| `error` | Significado |
|---|---|
| `unauthorized` | Token ausente/inválido. |
| `lock_timeout` | `LockService` não conseguiu lock em 10s. |
| `sheet_not_found` | Aba `Despesas` não existe na planilha. |
| `invoice_already_exists` | Já existe alguma linha com col A == `newClosing`. Inclui `invoiceClosing` na resposta. |
| `fixed_expenses_failed` | `loadFixedExpenses_()` lançou (aba `despesas-fixas` malformada). Inclui `detail` com mensagem original. |

## Edge cases

- **Sheet só com headers:** `findCurrentInvoice_` retorna `null`, `parcelaRows = []`. Bloco fica só com fixas. OK.
- **Fatura anterior sem parcelas:** após filter, `parcelaRows = []`. Idêntico ao caso do webhook.
- **Parcela `5/5` (última):** `X >= Y` → skip. Parcela já foi cobrada.
- **Parcela com formato não-padrão (ex: `"1/3 (estorno)"`, `"3"`, `""`):** regex falha → skip silencioso. A linha original permanece na fatura anterior; não é tocada.
- **Race webhook ↔ botão:** `LockService` serializa. O segundo (qualquer que seja) cai no dedup → `invoice_already_exists`.
- **Aba `despesas-fixas` malformada:** propaga via `buildInvoiceBlock_` → captura → `fixed_expenses_failed`. Planilha intocada (insert ainda não rodou).
- **Relógio do servidor errado / mudança de mês durante request:** `nextInvoiceClosingDate_()` chamada uma vez no início da request. Janela < 100ms. Aceitável.

## Implementações

- **Backend (autoritativo):** [apps-script/webhook/FixedExpenses.gs](../../../apps-script/webhook/FixedExpenses.gs) — `newInvoice_`, `previewNewInvoice_`, `buildInvoiceBlock_`, `applyInvoiceBlock_`.
- **Helpers:** [apps-script/shared/Helpers.gs](../../../apps-script/shared/Helpers.gs) — `newInvoiceClosingDate_(sheet)`, `latestInvoiceClosingInSheet_`, `findCurrentInvoice_`, `rolloverParcelaRow_`.
- **Dispatcher:** [apps-script/dashboard/Dashboard.gs](../../../apps-script/dashboard/Dashboard.gs) — `case "newInvoice"` em `doPost`, `case "newInvoicePreview"` em `doGet`.
- **Frontend:** [app/lib/features/inicio/inicio_page.dart](../../../app/lib/features/inicio/inicio_page.dart) — menu hambúrguer + dialog de confirmação (busca a data via `previewNewInvoice()`). [app/lib/api/endpoints.dart](../../../app/lib/api/endpoints.dart) — `newInvoice()` e `previewNewInvoice()`. (A antiga porta Dart `invoice_closing.dart` foi removida — o cálculo virou dependente da planilha.)

## Specs relacionadas

- [fixed-expenses.md](fixed-expenses.md) — origem do bloco de despesas fixas.
- [parcela-format.md](parcela-format.md) — formato `X/Y` na col I.
- [invoice-closing-date.md](invoice-closing-date.md) — cálculo da data de fechamento.
- [../api/endpoints.md](../api/endpoints.md) — endpoint REST.
- [../pages/inicio.md](../pages/inicio.md) — menu hambúrguer no app.
