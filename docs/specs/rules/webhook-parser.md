---
status: stable
last_updated: 2026-09-12
---

# Webhook parser — dois padrões de notificação

Extrai descrição, valor, data, hora e **banco** da notificação que o Tasker/IFTTT manda. Suporta dois padrões: Santander (texto rico, "banco antigo") e Revolut ("app novo"). O padrão que casou define o `banco` (col H); o final do cartão que aparece no texto do Santander é ignorado desde 2026-09-12 (ver [card-to-person.md](card-to-person.md), removido).

## Contexto

Hoje recebemos push de dois apps diferentes. O Santander entrega texto rico (uma única string com tudo); a Revolut entrega o nome do estabelecimento no `title` e só o valor no `text`, sem data nem hora. O parser detecta qual é a partir do `text` e usa o caminho apropriado.

A Revolut já mudou a copy da notificação uma vez (set/2026): de `😎 Pagou R$ 99,90 em …` para `Valor gasto: R$ 59,98.\nCrédito disponível: R$ 4.022,76.`. O regex aceita as duas variantes. Quando a copy muda de novo, o sintoma é linha em branco na planilha (ver "Falha de match").

## Regras

### Detecção (ordem de tentativa)

1. Se `text` casa com `NEW_APP_VALUE_RE` → caminho **app novo** (Revolut).
2. Senão → caminho **banco antigo** (`PURCHASE_RE`, Santander).

```js
const PURCHASE_RE =
  /Compra.+?final\s+\d+,.+?R\$\s*(-?[\d.,]+),.+?em\s+(\d{2}\/\d{2}\/\d{2,4}),.+?(\d{2}:\d{2}),\s*em\s+(.+?),\s*aprovada/i;

const NEW_APP_VALUE_RE = /(?:Pagou|Valor\s+gasto:?)\s+R\$\s*(-?[\d.,]+)/i;
```

`banco` resultante: `BANCO_SANTANDER` (`"Santander"`) se casou `PURCHASE_RE`; `BANCO_REVOLUT` (`"Revolut"`) se casou `NEW_APP_VALUE_RE`; `""` se nenhum. Constantes em `apps-script/shared/Constants.gs`.

### Caminho "banco antigo" — `PURCHASE_RE` (Santander)

Grupos:

| # | Conteúdo | Exemplo |
|---|----------|---------|
| 1 | `value` (BR string, antes de parse) | `89,50` |
| 2 | `refDate` | `03/04/26` ou `03/04/2026` |
| 3 | `refTime` | `14:32` |
| 4 | `description` (até `, aprovada`) | `MERCADO ABC` |

O trecho `final \d+` (últimos dígitos do cartão) continua obrigatório para o match, mas **não é capturado**: o número do cartão muda quando o plástico é trocado e não interessa ao modelo.

Pós-processamento:

- `refDate`: se ano de 2 dígitos (`26`), `normalizeDate_` prepende `"20"` → `"2026"`. Resultado canônico: `"DD/MM/YYYY"`.
- `value`: passa por `parseBrazilNumber_` → remove `.` (milhares), troca `,` por `.`, faz `parseFloat`. `NaN` → `""`.
- `description`: `.trim()`.
- `refTime`: usado verbatim (`"HH:MM"`).
- `banco`: `"Santander"`.

### Caminho "app novo" — `NEW_APP_VALUE_RE` (Revolut)

Exemplos de notificação (as duas variantes casam):

- Copy atual (set/2026):
  - `title`: `Cacau Jpa Comeri`
  - `text`: `Valor gasto: R$ 59,98.\nCrédito disponível: R$ 4.022,76.`
- Copy antiga:
  - `title`: `Mercado Livre`
  - `text`: `😎 Pagou R$ 99,90 em Mercado Livre Crédito Disponível: R$ 9.999,00`

Extração:

| Campo | Fonte |
|---|---|
| `description` | `title.trim()` |
| `value` | grupo 1 do `NEW_APP_VALUE_RE` → `parseBrazilNumber_` |
| `banco` | `"Revolut"` |
| `refDate` | `Utilities.formatDate(new Date(), tz, "dd/MM/yyyy")` |
| `refTime` | `Utilities.formatDate(new Date(), tz, "HH:mm")` |

A notificação não traz data/hora — usamos o instante do POST como aproximação (chega segundos depois da compra).

### Composição em `dataRef`

Ambos os caminhos: `refDateTime = refTime ? refDate + " " + refTime : refDate`. Vai para col B da planilha.

### Falha de match (ambos os padrões)

Se `text` não casa com nenhum dos dois regex, o parser retorna todos os campos vazios (`""`). O webhook **ainda insere** a linha (com col A preenchida pelo `latestInvoiceClosingInSheet_` e Origem `"Cartão"`), só com os campos extraídos vazios — útil para detectar regex stale na planilha.

## Edge cases

- **Valor negativo (banco antigo):** o regex aceita `-` no grupo 2. Estornos vão como negativos.
- **Estabelecimento com vírgula no nome (banco antigo):** o `(.+?)` é non-greedy, mas casa até a vírgula seguida de `"aprovada"`. Funciona se "aprovada" só aparece no fim.
- **`Crédito disponível: R$ 4.022,76` no app novo:** `NEW_APP_VALUE_RE` é ancorado em `Pagou R$` ou `Valor gasto: R$`, então só pega o valor da compra (59,98), nunca o limite disponível que vem depois.
- **Ponto final após o valor (`R$ 59,98.`):** o grupo `[\d.,]+` engole o `.` final → `"59,98."`. `parseBrazilNumber_` remove todos os `.` antes do `parseFloat`, então o resultado é `59.98` correto. Mesmo comportamento para `R$ 1.234,56.` → `1234.56`.
- **`title` vazio no app novo:** `description = ""`. Linha entra mesmo assim (consistente com falha de match).
- **Notificação em outro formato** (banco/app mudou copy): ambos os regex falham → linha em branco. Detectar pela rotina manual ao revisar Lançamentos. Aconteceu em set/2026 com a Revolut: dezenas de linhas em branco até o regex ser atualizado.
- **Multilinha:** o `text` da Revolut tem `\n` entre as duas frases. `NEW_APP_VALUE_RE` só usa `\s`, que casa newline, então funciona. `PURCHASE_RE` usa `.` sem flag `s`, então não casa através de newline — o Santander manda tudo em uma linha, como esperado. Se o `\n` chegar cru (não escapado) dentro do JSON, `doPost` tenta um fallback antes de rejeitar como `invalid_json` — ver [../api/webhook.md](../api/webhook.md).
- **`Compra` aparecer em outro contexto** (ex. notificação de promoção): tipicamente não tem `final \d+` na sequência, então não casa.

## Implementações

- **Backend (autoritativo):** [apps-script/webhook/Webhook.gs](../../../apps-script/webhook/Webhook.gs)
- **Helpers:** `parseBrazilNumber_`, `normalizeDate_` em [apps-script/shared/Helpers.gs](../../../apps-script/shared/Helpers.gs).
- **PWA / Flutter:** N/A. Não recebem webhook.

## Specs relacionadas

- [../api/webhook.md](../api/webhook.md)
- [../rules/invoice-closing-date.md](invoice-closing-date.md)
- [../data/despesas-sheet.md](../data/despesas-sheet.md) — col H (`Banco`)
