---
status: stable
last_updated: 2026-09-13
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
- `description`: passa por `sanitizeDescription_` (ver abaixo), igual ao caminho Revolut.
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
| `description` | `sanitizeDescription_(title)` |
| `value` | grupo 1 do `NEW_APP_VALUE_RE` → `parseBrazilNumber_` |
| `banco` | `"Revolut"` |
| `refDate` | `Utilities.formatDate(new Date(), tz, "dd/MM/yyyy")` |
| `refTime` | `Utilities.formatDate(new Date(), tz, "HH:mm")` |

A notificação não traz data/hora — usamos o instante do POST como aproximação (chega segundos depois da compra).

### Sanitização da descrição — `sanitizeDescription_`

A descrição extraída (dos **dois** caminhos) passa por `sanitizeDescription_` antes de ir para a col C. A Revolut manda o estabelecimento no `title` com emoji e espaço não separável (`NBSP`), ex.: `"Shopping Estação 🚎️"` ou `"Anthropic 🛍"`. A planilha deve guardar só o texto.

Ordem das operações:

1. Substitui cada caractere de emoji por **espaço** (não por vazio, pra não colar palavras: `"Uber🚗Eats"` → `"Uber Eats"`).
2. Substitui espaços Unicode (`NBSP`, narrow NBSP, ` - `, `　`, BOM) por espaço comum.
3. Colapsa runs de espaço em um só e faz `trim()`.

Faixas removidas (code units UTF-16, sem `\p{...}` de propósito — ver Edge cases):

```js
const EMOJI_RE =
  /[\u00A9\u00AE\u200D\u203C\u2049\u20E3\u2122\u2139\u2194-\u21AA\u231A-\u231B\u2328\u23CF\u23E9-\u23FA\u24C2\u25AA-\u25FE\u2600-\u27BF\u2934\u2935\u2B00-\u2BFF\u3030\u303D\u3297\u3299\uFE00-\uFE0F\u{1F000}-\u{1FAFF}\u{E0020}-\u{E007F}]/gu;

const UNICODE_SPACE_RE = /[\u00A0\u1680\u2000-\u200A\u202F\u205F\u3000\uFEFF]/g;
```

Cobre pictogramas (`U+1F300-1FAFF`), emoticons, bandeiras (regional indicators em `U+1F1E6-1F1FF` e tag chars em `U+E0020-E007F`), símbolos diversos e dingbats (`U+2600-27BF`), setas emoji, seletores de variação (`U+FE0F`), ZWJ (`U+200D`) e keycap (`U+20E3`). Modificadores de tom de pele (`U+1F3FB-1F3FF`) caem dentro de `1F000-1FAFF`.

**Pontuação não é tocada.** Nomes de estabelecimento legítimos usam `.`, `*`, `-`, `/` e `&` (ex.: `"SHOPEE .Jatobra"`, `"Br1*cafecomleitecal"`, `"MP .VIVA"`), então sanitizar pontuação quebraria o histórico e o classifier.

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
- **`title` só com emoji** (ex.: `"🛍"`): sanitização devolve `""`. A linha entra com valor e banco corretos e descrição vazia — mesmo tratamento de `title` vazio. Usuário corrige pelo modal de Lançamento.
- **Emoji no meio do nome:** vira espaço e o colapso resolve (`"Uber🚗Eats"` → `"Uber Eats"`). Nunca cola palavras.
- **`\p{Extended_Pictographic}` não é usado:** é ES2018 e, se o runtime não suportasse, o `SyntaxError` no literal derrubaria a carga de **todo** o script (todos os `.gs` compartilham escopo global) — foi o que aconteceu em 2026-09-12 com um `const` em ordem errada. Faixas explícitas em UTF-16 são previsíveis e só dependem de ES6 (`u` + `\u{...}`), já exigido pelo runtime V8 do projeto.
- **Classifier não muda:** `normalizeForClassify_` já descartava emoji (mantém só `[A-Z0-9\s]`). A sanitização afeta o que é **gravado**, não o match do classifier.
- **Dedup não muda:** o fingerprint usa `title`+`text` crus, então repetições continuam sendo descartadas do mesmo jeito.
- **Notificação em outro formato** (banco/app mudou copy): ambos os regex falham → linha em branco. Detectar pela rotina manual ao revisar Lançamentos. Aconteceu em set/2026 com a Revolut: dezenas de linhas em branco até o regex ser atualizado.
- **Multilinha:** o `text` da Revolut tem `\n` entre as duas frases. `NEW_APP_VALUE_RE` só usa `\s`, que casa newline, então funciona. `PURCHASE_RE` usa `.` sem flag `s`, então não casa através de newline — o Santander manda tudo em uma linha, como esperado. Se o `\n` chegar cru (não escapado) dentro do JSON, `doPost` tenta um fallback antes de rejeitar como `invalid_json` — ver [../api/webhook.md](../api/webhook.md).
- **`Compra` aparecer em outro contexto** (ex. notificação de promoção): tipicamente não tem `final \d+` na sequência, então não casa.

## Implementações

- **Backend (autoritativo):** [apps-script/webhook/Webhook.gs](../../../apps-script/webhook/Webhook.gs)
- **Helpers:** `parseBrazilNumber_`, `normalizeDate_`, `sanitizeDescription_` em [apps-script/shared/Helpers.gs](../../../apps-script/shared/Helpers.gs).
- **PWA / Flutter:** N/A. Não recebem webhook.

## Specs relacionadas

- [../api/webhook.md](../api/webhook.md)
- [../rules/invoice-closing-date.md](invoice-closing-date.md)
- [../data/despesas-sheet.md](../data/despesas-sheet.md) — col H (`Banco`)
