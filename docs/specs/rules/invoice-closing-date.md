---
status: stable
last_updated: 2026-08-01
---

# Invoice closing date — `nextInvoiceClosingDate_` e `newInvoiceClosingDate_`

Duas funções com semântica diferente:

- **`nextInvoiceClosingDate_`** — fatura **atual acumulando** (próxima a fechar), computada a partir de `now`. Usada pelo webhook ao gravar uma compra: a compra entra na fatura que ainda está aberta.
- **`newInvoiceClosingDate_(sheet)`** — fatura **imediatamente seguinte à última que já existe na planilha** (maior data da col A + 1 mês). Usada pelo gatilho manual "Nova fatura" (ver [new-invoice.md](new-invoice.md)). **Ancorada no estado da planilha, não em `now`.**

## Contexto

A col A não é a data da compra (essa fica em col B, `dataRef`). É o **fechamento da fatura** em que a linha entra.

Ex.: `INVOICE_CLOSING_DAY = 6`.
- Compras feitas hoje (`26/05/2026`) vão para a fatura que fecha em `06/06/2026` (a acumulando). `nextInvoiceClosingDate_` retorna `06/06/2026`.
- "Nova fatura" (manual): se a fatura mais recente na planilha fecha em `06/07/2026`, cria a de `06/08/2026`. `newInvoiceClosingDate_(sheet)` retorna `06/08/2026` — **independente da data de hoje**.

A diferença vem do gatilho:
- Webhook reage a um evento real (compra) — a compra precisa entrar na fatura que está acumulando **agora** (por isso usa `now`).
- "Nova fatura" continua a sequência de faturas já materializadas: cria sempre a **próxima depois da última que existe na base**, seja qual for o dia de hoje. Isso evita "pular" meses quando o usuário roda o gatilho tarde (ex.: só em agosto, mas a última fatura na planilha ainda é a de julho → cria agosto, não outubro). Mesma filosofia que o webhook já adota via `latestInvoiceClosingInSheet_`.

## Regras

### `nextInvoiceClosingDate_() → string "DD/MM/YYYY"`

1. `now` = data atual no timezone do script.
2. `year`, `month` = ano/mês atual.
3. `nextMonth = month + 1`. Se `> 12`, `nextMonth = 1`, `nextYear = year + 1`. (Senão `nextYear = year`.)
4. `dd` = `INVOICE_CLOSING_DAY` zero-padded a 2 dígitos.
5. `mm` = `nextMonth` zero-padded.
6. Retorna `"${dd}/${mm}/${nextYear}"`.

### `newInvoiceClosingDate_(sheet) → string "DD/MM/YYYY"`

Um mês após a **última fatura registrada na planilha**:

1. `latest = latestInvoiceClosingInSheet_(sheet)` — maior data da col A (string `DD/MM/YYYY`), ou `null` se a aba só tem headers.
2. **Fallback:** se `latest === null` (primeiríssima fatura), retorna `nextInvoiceClosingDate_()` (a acumulando a partir de hoje).
3. Senão: `mm = parseInt(latest.split("/")[1]) + 1`. Se `> 12`, `mm = 1`, `yyyy += 1`.
4. `dd = INVOICE_CLOSING_DAY` (não o dia de `latest`) — a fatura sempre fecha no dia padrão.
5. Retorna `"${dd}/${mm}/${yyyy}"`.

Recebe `sheet` (a aba `Despesas`) porque o cálculo depende do estado da planilha. `newInvoice_` chama **dentro do `LockService`**, após abrir a aba, pra ler um estado consistente. O cliente não computa essa data localmente — usa o endpoint de preview (ver [new-invoice.md](new-invoice.md)).

`INVOICE_CLOSING_DAY` é uma constante (atualmente `6`). Trocar de banco/cartão pode exigir ajuste — mudar a constante é o ponto único.

## Edge cases

- **Compra exatamente no dia de fechamento:** segundo essa regra, ainda entra na fatura do mês seguinte. Se na prática o banco trata diferente, o usuário pode editar a col A manualmente; mas o webhook não sabe distinguir.
- **Mudança de timezone do script:** afeta `now`. O timezone é configurado no Apps Script (Project Settings); padrão `America/Sao_Paulo`.
- **Cartão com data de fechamento diferente por bandeira:** não suportado. Mudar a regra para multi-cartão exigiria lookup por `cardLast4` no [card-to-person.md](card-to-person.md). Não está em escopo.

## Implementações

- **Backend (autoritativo):** [apps-script/shared/Helpers.gs](../../../apps-script/shared/Helpers.gs) — `nextInvoiceClosingDate_`, `newInvoiceClosingDate_(sheet)`, `latestInvoiceClosingInSheet_`.
- **Constante:** [apps-script/shared/Constants.gs](../../../apps-script/shared/Constants.gs) — `INVOICE_CLOSING_DAY`.
- **Flutter:** sem porta Dart. O dialog de Nova fatura busca a data no backend via endpoint `newInvoicePreview` (o cálculo depende do estado da planilha). O antigo `app/lib/core/rules/invoice_closing.dart` foi removido.
- **PWA legacy (React):** N/A.

## Specs relacionadas

- [../api/webhook.md](../api/webhook.md)
- [../data/despesas-sheet.md](../data/despesas-sheet.md) — col A
- [fixed-expenses.md](fixed-expenses.md) — usa o mesmo `invoiceClosing` para detectar fatura nova
- [new-invoice.md](new-invoice.md) — usa `newInvoiceClosingDate_` (semântica diferente do webhook)
