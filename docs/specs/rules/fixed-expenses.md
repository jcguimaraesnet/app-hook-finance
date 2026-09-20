---
status: stable
last_updated: 2026-05-26
---

# Fixed expenses — inserção mensal manual (Nova fatura)

Despesas recorrentes (Diarista, Plano de Saúde, Creche, etc.) são inseridas no início de cada fatura nova pelo gatilho manual Nova fatura.

## Contexto

O usuário não precisa lançar manualmente despesas que ele sabe que vão acontecer todo mês. O botão **Nova fatura** (menu hambúrguer na aba Início — ver [../pages/inicio.md](../pages/inicio.md)) chama o endpoint `?action=newInvoice`, que monta e insere o bloco no topo da planilha. Esse bloco também marca visualmente o início da fatura (linha azul) e inclui o rollover de parcelas pendentes.

> **Histórico:** anteriormente (antes de 2026-05-26) o webhook chamava `appendMonthlyFixedIfNeeded_` para inserir despesas fixas na primeira compra de Cartão de cada fatura. Esse gatilho foi removido — webhook agora só empilha compras na última fatura existente, sem criar bloco. Ver [../api/webhook.md](../api/webhook.md).

## Regras

### Trigger

`newInvoice_(token)` em [FixedExpenses.gs](../../../apps-script/webhook/FixedExpenses.gs) é chamado via POST `?action=newInvoice` (ver [new-invoice.md](new-invoice.md) para o algoritmo completo). O fluxo de inserção das despesas fixas:

1. `buildInvoiceBlock_(invoiceClosing, parcelaRows)` chama `loadFixedExpenses_()` para ler/validar a aba `despesas-fixas` ([../data/despesas-fixas-sheet.md](../data/despesas-fixas-sheet.md)).
2. Monta o bloco com despesas fixas + linhas de parcela rolada (se houver) + delimitadores.
3. `applyInvoiceBlock_` insere via `insertRowsBefore(2, N)` + `setValues` + pinta linha azul.

Dedup é feito em `newInvoice_` antes de chamar `buildInvoiceBlock_`: se qualquer linha já tem `col A === newClosing`, retorna `invoice_already_exists` e não insere.

### Bloco inserido

Composto pelo retorno de `loadFixedExpenses_()` em [FixedExpenses.gs](../../../apps-script/webhook/FixedExpenses.gs), que lê e valida a aba [despesas-fixas](../data/despesas-fixas-sheet.md). Cada item retornado:

```js
{
  refDay: <1-31>,
  description: <string>,
  value: <number>,
  origem: <string>,
  categoria: <string>,
  rateio: "Julio" | "Dani" | "Metade" | "Alzira",
  acerto: "" | "Sim",
}
```

Para cada item, o backend constrói uma row:

| Col | Valor |
|-----|-------|
| A | `parseBrDate_(invoiceClosing)` (Date object — exibido como `dd/MM/yyyy`) |
| B | `${dd}/${mm}/${yyyy}` onde `dd = refDay`, `mm/yyyy` = mês/ano da fatura |
| C | `description` |
| D | `value` |
| E | `origem` (sempre `"Débito"` na lista atual) |
| F | `categoria` |
| G | `rateio` |
| H | `""` (n/a para Pix) |
| I | `""` (despesas fixas nunca são parceladas) |
| J | `acerto || ""` |

### Layout no sheet

Layout completo (incluindo rollover de parcelas — ver [new-invoice.md](new-invoice.md)) está documentado em new-invoice.md. Sem parcelas roladas, o bloco vira:

```
[blank row]
[fixed expense 1]
...
[fixed expense N]
[blank row]
[blank row — pintada de azul (#cfe2f3) para sinalizar início da fatura visualmente]
[blank row]
```

Inserido via `applyInvoiceBlock_(sheet, block)` → `insertRowsBefore(2, N)` + `setNumberFormat("dd/MM/yyyy")` na col A + `setNumberFormat("@")` na col I + `setValues` + background azul. Linha azul vai na **penúltima** posição do bloco.

### Lista atual de despesas fixas

Lista vive na aba `despesas-fixas` da planilha — schema em [../data/despesas-fixas-sheet.md](../data/despesas-fixas-sheet.md). Edição direta no Sheets, sem deploy.

Mudanças refletem na próxima fatura inserida. Não retroativo.

## Edge cases

- **Nova fatura disparada 2x:** segundo call cai no dedup de `newInvoice_` (`invoice_already_exists`). Bloco não duplica.
- **Refday no fim do mês ausente** (ex.: refDay=31 em fevereiro): gera string `"31/02/yyyy"` em col B (inválido como data, mas válido como string). Funciona porque col B é tratada como string. Tratamento ideal seria clamp para último dia válido do mês — não está implementado.
- **`value = 0`** (linha placeholder, ex. `"Condomínio 1/2 (Dani)"`): inserida igual; não polui totais (zero).
- **Aba `despesas-fixas` ausente, vazia, ou com linha malformada:** `loadFixedExpenses_()` lança erro `despesas-fixas L{N}: ...`. `newInvoice_` captura e retorna `{ ok: false, error: "fixed_expenses_failed", detail }` sem inserir nada. Frontend mostra SnackBar com a mensagem.

## Implementações

- **Backend (autoritativo):** [apps-script/webhook/FixedExpenses.gs](../../../apps-script/webhook/FixedExpenses.gs) — `loadFixedExpenses_()` (lê/valida aba), `buildInvoiceBlock_` + `applyInvoiceBlock_` (montagem/aplicação do bloco), `newInvoice_` (endpoint). Função one-shot `seedFixedExpenses()` para popular a aba inicialmente (sem `_` no fim — precisa aparecer no dropdown do editor pra execução manual).
- **Configuração:** aba `despesas-fixas` na planilha — schema em [../data/despesas-fixas-sheet.md](../data/despesas-fixas-sheet.md).
- **PWA / Flutter:** consome via dialog "Nova fatura" em [app/lib/features/inicio/inicio_page.dart](../../../app/lib/features/inicio/inicio_page.dart).

## Specs relacionadas

- [../api/webhook.md](../api/webhook.md)
- [invoice-closing-date.md](invoice-closing-date.md)
- [../data/despesas-sheet.md](../data/despesas-sheet.md)
- [new-invoice.md](new-invoice.md) — gatilho manual que reusa `loadFixedExpenses_()` e o helper de bloco.
