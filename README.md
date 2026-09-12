# hook-finance

- **PWA (Azure SWA)**: [clique aqui](https://polite-mushroom-0d3d07a0f.7.azurestaticapps.net/)
- **Projeto Apps Script**: [clique aqui](https://script.google.com/home/projects/1HvwjDc_t-XIi1SmZnq5gxrZoTBEw7GlDx98d-UolqRAQBk0BBvGwz9E1/edit)
- **Backend (Apps Script `/exec`)**: [clique aqui](https://script.google.com/macros/s/AKfycby7v9mrOGHV6tIaiOmgs7ZaGolmSTXsEKIj3rYjBlYalePcuBmSM0C35Wc5-vJZRNE-7Q/exec)

Webhook em Google Apps Script que recebe `POST` com notificações de compra no cartão (campos `title` e `text` no body), faz parse do texto, e grava uma nova linha estruturada em uma Google Sheet. Deploy automatizado via GitHub Actions com [`clasp`](https://github.com/google/clasp).

## Estrutura

```
src/
  appsscript.json              # manifest (scopes + webapp config)
  shared/
    Constants.gs               # SHEET_ID, SHEET_NAME, ORIGEM, INVOICE_CLOSING_DAY
    Helpers.gs                 # jsonResponse_, formatBrDate_, parseBrazilNumber_, ...
    Setup.gs                   # setupToken (rodar 1x manualmente)
  webhook/
    Webhook.gs                 # doPost + parser de notificação
    FixedExpenses.gs           # despesas fixas inseridas no início da fatura
  dashboard/
    Dashboard.gs               # doGet + getDataForDashboard (google.script.run)
    Index.html                 # markup
    Stylesheet.html            # CSS responsivo (mobile-first)
    Script.html                # JS de agregação + Chart.js
.clasp.json                    # vincula ao projeto Apps Script remoto
.github/workflows/deploy.yml
```

> Todos os `.gs` rodam no mesmo escopo global do Apps Script — chamadas como `jsonResponse_()` em `webhook/Webhook.gs` resolvem para a função em `shared/Helpers.gs` sem `import`.

## Setup local (uma vez)

1. Instalar dependências:
   ```bash
   npm install
   ```
2. Login no clasp (abre navegador):
   ```bash
   npx clasp login
   ```
3. Criar o projeto Apps Script (ou usar um existente):
   ```bash
   npx clasp create --type standalone --title hook-finance --rootDir src
   ```
   Isso preenche o `scriptId` em `.clasp.json`. Se já tem um projeto, edite manualmente.
4. Criar a planilha Google Sheets que vai receber os dados. Pegue o `SHEET_ID` da URL (`https://docs.google.com/spreadsheets/d/<SHEET_ID>/edit`) e cole em [apps-script/shared/Constants.gs](apps-script/shared/Constants.gs). Ajuste `SHEET_NAME` se a aba não for `Sheet1`.
5. Adicione o cabeçalho na linha 1 da planilha (ver [Esquema da planilha](#esquema-da-planilha) abaixo).

## Configurar o token do webhook

No editor do Apps Script (após o primeiro `clasp push`):

1. Abra o projeto: `npx clasp open`.
2. Edite a função `setupToken` em [apps-script/shared/Setup.gs](apps-script/shared/Setup.gs) colocando um token forte e rode-a uma vez (botão Run). Isso grava em **Project Settings → Script Properties** a chave `WEBHOOK_TOKEN`.
3. Alternativa: vá direto em **Project Settings → Script Properties → Add script property** e crie `WEBHOOK_TOKEN` manualmente.

## Primeiro deploy (manual, para autorizar scopes)

O Apps Script exige autorização interativa antes do primeiro request:

1. No editor, **Deploy → New deployment → Web app**.
2. Execute as: **Me**, Who has access: **Anyone**.
3. Autorize os scopes (Sheets + external request).
4. Copie a **Web app URL** — é o endpoint do webhook.

## Configurar o GitHub Action

1. Crie o repositório no GitHub e faça push.
2. No GitHub: **Settings → Secrets and variables → Actions → New repository secret**:
   - Nome: `CLASPRC_JSON`
   - Valor: conteúdo do arquivo `~/.clasprc.json` (gerado pelo `clasp login`).
     ```bash
     cat ~/.clasprc.json
     ```
3. A partir daí, todo push em `main` que altere `src/**` aciona `clasp push` + `clasp deploy`.

## Esquema da planilha

A linha 1 da planilha deve ter os seguintes cabeçalhos, na ordem:

| # | Coluna | Conteúdo |
|---|---|---|
| 1 | Data | Data de fechamento da fatura (regra: dia 06 do mês seguinte ao mês atual). |
| 2 | Data Referência | Data e hora da compra extraídas do texto (`DD/MM/YYYY HH:MM`). |
| 3 | Descrição | Estabelecimento extraído do texto (ex.: `SUPERMERCADOS V`). |
| 4 | Valor | Valor numérico da compra (ex.: `32,78`). |
| 5 | Origem | Sempre `Cartão` (constante). |
| 6 | Categoria | Inferida via [Classifier](apps-script/webhook/Classifier.gs) a partir do histórico. Vazia se não houver match suficiente. |
| 7 | Rateio | Inferido via [Classifier](apps-script/webhook/Classifier.gs) a partir do histórico. Valores possíveis: `Julio`, `Dani`, `Metade`, `Alzira`. Vazio se não houver match suficiente. |
| 8 | Banco | `Santander` ou `Revolut`, decidido pelo padrão da notificação que casou (ver "Formato esperado do `text`"). Vazio se nenhum padrão casou. Até 2026-09-12 guardava os 4 dígitos finais do cartão; migração via `migrateCardToBanco()` em [apps-script/shared/Maintenance.gs](apps-script/shared/Maintenance.gs). |
| 9 | Parcela | String no formato `parcela_atual/total` (ex: `1/3` = 1ª de 3). Vazio quando à vista. Editável pelo modal da aba Lançamento via [updateEntry](apps-script/dashboard/Dashboard.gs) — o stepper edita só o total; parcela_atual é sempre gravada como `1`. |
| 10 | Acerto | `Sim` quando a linha deve entrar no rateio do "Acerto Final". Vazio caso contrário. |

Constantes que controlam o comportamento:

- `INVOICE_CLOSING_DAY` em [apps-script/shared/Constants.gs](apps-script/shared/Constants.gs) — dia do fechamento da fatura (default `6`).
- `ORIGEM` em [apps-script/shared/Constants.gs](apps-script/shared/Constants.gs) — texto fixo da coluna Origem para webhook (default `Cartão`).
- `PURCHASE_RE` em [apps-script/webhook/Webhook.gs](apps-script/webhook/Webhook.gs) — regex do Santander: extrai cartão, valor, data, hora e descrição do texto.
- `NEW_APP_VALUE_RE` em [apps-script/webhook/Webhook.gs](apps-script/webhook/Webhook.gs) — regex da Revolut: extrai só o valor do texto; descrição vem do `title`, cartão é fixo `2236`, data/hora é o instante do POST.

### Classificação automática (Categoria/Rateio)

Quando uma compra de cartão chega, o webhook tenta inferir `Categoria` e `Rateio` olhando o histórico:

- Considera apenas linhas com `Origem = Cartão` que já tenham `Categoria` ou `Rateio` preenchidos.
- Calcula similaridade Jaccard entre tokens normalizados (uppercase, sem acentos, sem pontuação, sem stop-words tipo `LJ`, `FILIAL`, `BR`, `LTDA`).
- Score ≥ `CLASSIFY_THRESHOLD` (default `0.4`) → copia `Categoria` e `Rateio` da linha mais similar (empate → mais recente vence).
- Sem match suficiente → as duas colunas ficam vazias para você preencher manualmente.

Exemplo: se você classificou uma vez `"AMAZON BR"` como `Categoria = Compras / Rateio = Metade`, da próxima vez que vier `"AMAZON.COM.BR LJ 09"` o sistema completa sozinho.

Lógica em [apps-script/webhook/Classifier.gs](apps-script/webhook/Classifier.gs). Para tunar: ajustar `CLASSIFY_THRESHOLD` ou `CLASSIFY_STOP_WORDS`.

### Despesas fixas mensais

O webhook **não** cria o bloco de início de fatura. Ele sempre grava a compra na última fatura já registrada na planilha (maior data da coluna A). O bloco de despesas fixas + linha azul + rollover de parcelas é criado apenas pelo gatilho manual "Nova fatura" no app, no início de cada mês. A lista de despesas fixas vive na aba `despesas-fixas` da planilha e é lida por [apps-script/webhook/FixedExpenses.gs](apps-script/webhook/FixedExpenses.gs). Regras em [docs/specs/rules/new-invoice.md](docs/specs/rules/new-invoice.md).

### Formato esperado do `text`

Dois padrões, detectados pelo conteúdo do `text` (spec: [docs/specs/rules/webhook-parser.md](docs/specs/rules/webhook-parser.md)):

**Santander** (`title` ignorado; tudo vem do `text`):
```
Compra no cartão final 0784, de R$ 13,99, em 10/09/26, às 12:29, em VM.MERCADOS, aprovada.
```

**Revolut** (`title` é a descrição; `text` só tem o valor):
```
title: Cacau Jpa Comeri
text:  Valor gasto: R$ 59,98.
       Crédito disponível: R$ 4.022,76.
```
A copy antiga da Revolut (`😎 Pagou R$ 99,90 em …`) também é aceita.

Se o texto não casar com nenhum dos dois regex, a linha ainda é gravada, mas só com a coluna 1 (fatura) e a coluna 5 (`Cartão`) preenchidas. Uma sequência de linhas assim na planilha é o sinal de que o banco mudou a copy da notificação.

## Testar o webhook

### Caminho recomendado — via proxy

Use o endpoint `/api/proxy` do Azure Function. Ele segue o redirect 302 do Apps Script preservando método e body, então o POST chega íntegro:

```bash
curl -X POST "https://polite-mushroom-0d3d07a0f.7.azurestaticapps.net/api/proxy" \
  -H "Content-Type: application/json; charset=utf-8" \
  -d '{"title":"Compra Aprovada!","text":"Compra no cartão final 1018, de R$ 32,78, em 01/05/26, às 18:33, em SUPERMERCADOS V, aprovada.","token":"<WEBHOOK_TOKEN>"}'
```

Resposta:
```json
{"ok":true}
```

### Caminho direto (`/exec`) — cuidado

POST direto em `https://script.google.com/macros/s/<DEPLOYMENT_ID>/exec` retorna 302 → `script.googleusercontent.com/macros/echo?...`. O `curl -L` padrão converte POST em GET no redirect, e mesmo com `--post301 --post302 --post303` o segundo hop frequentemente devolve a página HTML "Página não encontrada" do Google Drive (problema de auth/cookie no caminho direto). Por isso o caminho via proxy é o seguro. Se ainda assim quiser testar direto, o Tasker/IFTTT funciona porque o cliente HTTP nativo do Android trata o redirect como o `fetch` do Node faz.

### Estrutura obrigatória do request

| Item | Valor |
|---|---|
| Método | `POST` |
| Header | `Content-Type: application/json; charset=utf-8` |
| Body | JSON com **exatamente** três campos: `title`, `text`, `token` |

```json
{
  "title": "Compra Aprovada!",
  "text": "Compra no cartão final 1018, de R$ 32,78, em 01/05/26, às 18:33, em SUPERMERCADOS V, aprovada.",
  "token": "<WEBHOOK_TOKEN>"
}
```

### Formato do `text` (regra do regex)

**Santander.** O `PURCHASE_RE` em [Webhook.gs](apps-script/webhook/Webhook.gs) exige **vírgulas** como separador entre os campos da notificação:

```
Compra no cartão final <CARD>, de R$ <VALOR>, em <DD/MM/YY[YY]>, às <HH:MM>, em <DESCRICAO>, aprovada.
```

Se você usar pontos no lugar das vírgulas (ex.: `final 4750.de R$ 19.90.`), o regex não casa, `parsePurchase_` devolve campos vazios e a linha é gravada na planilha **com tudo em branco** — backend ainda responde `{"ok":true}`. Esse é o sintoma mais comum de "deu certo mas não preencheu nada".

**Revolut.** O `NEW_APP_VALUE_RE` só precisa achar `Valor gasto: R$ <VALOR>` (ou `Pagou R$ <VALOR>`) em qualquer lugar do `text`. A quebra de linha antes de `Crédito disponível` não atrapalha. Teste:

```bash
curl -X POST "https://polite-mushroom-0d3d07a0f.7.azurestaticapps.net/api/proxy" \
  -H "Content-Type: application/json; charset=utf-8" \
  -d '{"title":"Cacau Jpa Comeri","text":"Valor gasto: R$ 59,98.\nCrédito disponível: R$ 4.022,76.","token":"<WEBHOOK_TOKEN>"}'
```

Se o job do celular mandar a quebra de linha **crua** (sem escapar como `\n`), o `doPost` escapa e tenta o parse de novo antes de rejeitar como `invalid_json`.

### Dedup automática (5 minutos)

O webhook calcula `SHA-256(title + "\n" + text)` e guarda em `CacheService` por 300s. Reenviar o mesmo `title+text` dentro da janela retorna `{"ok":true,"deduped":true}` sem inserir nova linha. Pra forçar uma nova inserção antes da janela expirar, mude qualquer caractere do `text` (o hash muda). Constante: `DEDUP_WINDOW_SECONDS` em [Webhook.gs](apps-script/webhook/Webhook.gs).

### Erros possíveis

| Resposta | Causa |
|---|---|
| `{"ok":true,"deduped":true}` | Mesmo `title+text` já recebido nos últimos 5 min. |
| `{"ok":false,"error":"unauthorized"}` | `token` ausente ou diferente do `WEBHOOK_TOKEN` em Script Properties. |
| `{"ok":false,"error":"missing_fields"}` | `title` ou `text` vazio/ausente. |
| `{"ok":false,"error":"invalid_json"}` | Body não é JSON válido, nem depois de escapar `\r`/`\n`/`\t` crus. |
| `{"ok":false,"error":"lock_timeout"}` | `LockService` não conseguiu adquirir o lock em 10s (concorrência alta). |
| `{"ok":false,"error":"sheet_not_found"}` | `SHEET_NAME` não existe na planilha. |

## Dashboard

O dashboard roda como **PWA Flutter** em `https://polite-mushroom-0d3d07a0f.7.azurestaticapps.net/` (mesmo codebase Flutter que gera o APK Android, hospedado no Azure Static Web Apps via [.github/workflows/deploy-web.yml](.github/workflows/deploy-web.yml)). O Apps Script ficou apenas como backend JSON — abrir o `/exec` direto sem `?action=...` retorna `{ok:false,error:"unknown_action"}`.

- **Direção visual**: Bloom (lavanda + menta), bottom-nav 5 abas (Início · Compart · Lançamentos · Histórico · Acerto). Mesma identidade do APK.
- **Auth**: pede o `WEBHOOK_TOKEN` no login. O token é validado antes de ser salvo (`SharedPreferences` no Android, `localStorage` no web). Biometria disponível só no APK.
- **Comunicação**: a app chama `/api/proxy?action=...` (Azure Function em [web/api/proxy/](web/api/proxy/)) que repassa para o `/exec` do Apps Script. Em produção é same-origin (sem CORS no browser); o proxy também envia headers CORS para permitir dev local (`flutter run -d chrome`) sem flags.
- **Endpoint JSON legado** (debug): `GET <WEB_APP_URL>?action=data&token=<TOKEN>` ainda retorna `{ok, rows[]}`.
- **Logout**: pelo botão dentro do app, ou (debug) limpando storage do navegador.
- **PWA install**: Chrome/Edge desktop e Safari iOS suportam "Adicionar à Tela de Início" — ícone Bloom + standalone (sem barra do navegador).

## Comandos úteis

```bash
npm run push     # clasp push -f
npm run deploy   # clasp deploy
npm run pull     # baixa do remoto (caso edite via UI)
```

### ⚠ `clasp push` / `clasp deploy` local vs. GitHub Action

`clasp push` e `clasp deploy` rodando da sua máquina enviam o conteúdo da pasta `src/` **direto pros servidores do Apps Script**, sem passar por git/GitHub. Use para iterar rápido durante desenvolvimento.

**Risco**: a produção (Apps Script) e o repo (GitHub) ficam fora de sync enquanto você não comita. Se a [GitHub Action](.github/workflows/deploy.yml) rodar a partir do último commit (push em `main`), ela vai sobrescrever a produção com a versão antiga do repo — efetivamente **revertendo** tudo que você empurrou local.

Regra prática:
1. Itere local com `npm run push` (e `npm run deploy` quando quiser atualizar a versão servida do deployment fixo).
2. Quando estabilizar, **comite e dê push em `main`** — a Action re-empurra (sem mudanças), produção e repo voltam alinhados.
3. Antes de qualquer push em `main`, confira `git status` — não pode ter divergência silenciosa entre `src/` no repo e o que tá em produção.
