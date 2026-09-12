---
status: stable
last_updated: 2026-09-12
---

# Webhook (Tasker / IFTTT)

Recebe notificações de compra do app de notificação Android e insere uma linha em `Despesas`. Reusa `doPost` global do Apps Script.

## Contexto

Santander e Revolut enviam push notification ao Android. Um job no celular (Tasker ou similar) captura título/texto e dispara `POST` para o Apps Script. O Apps Script extrai descrição, valor e data da string, identifica o banco pelo padrão do texto, e insere no topo da planilha **na última fatura já registrada na planilha**.

> Webhook NÃO cria mais o bloco de "início de fatura" (despesas fixas + linha azul). Esse bloco é criado **apenas** pelo gatilho manual Nova fatura — ver [../rules/new-invoice.md](../rules/new-invoice.md). Fluxo esperado: usuário clica Nova fatura no início do mês → bloco criado → webhook empilha as compras nessa fatura ao longo do mês.

## Regras

- **Endpoint:** mesmo `doPost` do REST. Distinção: body tem `title` E `text`.
- **Parse do body:** `JSON.parse` estrito primeiro. Se falhar, `parsePostBody_` escapa `\r`, `\n` e `\t` crus e tenta de novo (a notificação da Revolut tem quebra de linha, e o job do celular pode não escapá-la). Se ainda assim não for JSON → `{ ok: false, error: "invalid_json" }`.
- **Body esperado (Santander — "banco antigo"):**
  ```json
  {
    "title": "Compra aprovada!",
    "text": "Compra no cartão final 0784, de R$ 13,99, em 10/09/26, às 12:29, em VM.MERCADOS, aprovada.",
    "token": "<WEBHOOK_TOKEN>"
  }
  ```
- **Body esperado (Revolut — "app novo"):**
  ```json
  {
    "title": "Cacau Jpa Comeri",
    "text": "Valor gasto: R$ 59,98.\nCrédito disponível: R$ 4.022,76.",
    "token": "<WEBHOOK_TOKEN>"
  }
  ```
  Padrão diferente: `title` carrega a descrição da despesa direto; `text` só tem o valor (sem data/hora). Parser detecta pelo match de `Valor gasto: R$` (ou `Pagou R$`, copy antiga) no `text` e grava `banco = "Revolut"`. Data/hora viram o instante do POST. Ver [../rules/webhook-parser.md](../rules/webhook-parser.md).
- **Token:** mesmo `WEBHOOK_TOKEN` dos endpoints REST. Verificado por igualdade exata.
- **Sem token / token inválido:** `{ ok: false, error: "unauthorized" }`.
- **`title` ou `text` vazio:** `{ ok: false, error: "missing_fields" }`.
- **Lock:** `LockService.getScriptLock().tryLock(10000)`. Timeout → `{ ok: false, error: "lock_timeout" }`.
- **Dedup:** SHA-256 de `title + "\n" + text` é guardado em `CacheService.getScriptCache()` por 300s. Hit → `{ ok: true, deduped: true }` (sem inserir). Ver [../rules/webhook-dedup.md](../rules/webhook-dedup.md).
- **Parser:** [../rules/webhook-parser.md](../rules/webhook-parser.md) detecta o padrão (banco antigo via `PURCHASE_RE` ou app novo via `NEW_APP_VALUE_RE`). Se nenhum casar, descricao/valor/data ficam vazios mas a linha é inserida mesmo assim com `Data` (col A) e `Origem = "Cartão"`.
- **Inserção:**
  - col A (Data): `latestInvoiceClosingInSheet_(sheet)` (string da fatura mais recente já na planilha) → convertido para `Date` via `parseBrDate_`. Fallback para `nextInvoiceClosingDate_()` apenas se a planilha estiver vazia. Force `setNumberFormat("dd/MM/yyyy")` após insert.
  - col B (Data Referência): `"DD/MM/YYYY HH:MM"` ou só data se hora indisponível.
  - col C (Descrição): texto extraído.
  - col D (Valor): número extraído.
  - col E (Origem): `"Cartão"` (constante `ORIGEM`).
  - col F/G (Categoria/Rateio): inferidos por `classifyFromHistory_` — ver [../rules/classifier.md](../rules/classifier.md). Vazios se score < `CLASSIFY_THRESHOLD`.
  - col H (Banco): `"Santander"` ou `"Revolut"` conforme o regex que casou; `""` se nenhum.
  - col I/J (Parcela/Acerto): vazios.
- **Despesas fixas:** webhook não cria mais bloco. Use Nova fatura ([../rules/new-invoice.md](../rules/new-invoice.md)) para criar o bloco antes de receber compras de uma nova fatura.

## Edge cases

- **Lock timeout:** o cliente (Tasker) deve fazer retry; conteúdo idempotente via dedup.
- **Notificação reenviada (replay):** dedup descarta; resposta `ok: true, deduped: true`.
- **Texto que não casa com nenhum regex:** linha entra com campos vazios (só col A e Origem). Útil pra detectar regex stale. Caso real: set/2026, Revolut trocou `Pagou R$` por `Valor gasto: R$` e gerou dezenas de linhas em branco até o regex ser atualizado. Ao ver linhas assim, comparar a notificação atual com [../rules/webhook-parser.md](../rules/webhook-parser.md).
- **Planilha vazia (degenerado):** fallback para `nextInvoiceClosingDate_()`. Compra entra na fatura computada de hoje, mas sem despesas fixas (webhook não cria bloco). Usuário deve rodar Nova fatura assim que possível.
- **Última fatura registrada é antiga (ex.: 06/05 e hoje é 26/05):** compra entra em 06/05 (fatura já fechada). Usuário deve rodar Nova fatura para criar 06/06 — depois disso webhook escreve em 06/06.
- **Cartão novo / final desconhecido:** irrelevante desde 2026-09-12. O banco vem do padrão do texto, não do número do cartão; trocar de plástico não exige mudança no app.

## Implementações

- **Backend (autoritativo):** [apps-script/webhook/Webhook.gs](../../../apps-script/webhook/Webhook.gs)
- **PWA/Flutter:** não consomem este endpoint diretamente (write-only do Tasker).

## Specs relacionadas

- [../rules/webhook-parser.md](../rules/webhook-parser.md)
- [../rules/webhook-dedup.md](../rules/webhook-dedup.md)
- [../rules/classifier.md](../rules/classifier.md)
- [../rules/invoice-closing-date.md](../rules/invoice-closing-date.md)
- [../rules/fixed-expenses.md](../rules/fixed-expenses.md)
- [../data/despesas-sheet.md](../data/despesas-sheet.md) — col H (`Banco`)
- [endpoints.md](endpoints.md)
