---
status: stable
last_updated: 2026-05-07
---

# Conventions

Convenções globais que valem em todas as codebases (Apps Script, PWA, Flutter).

## Idioma

- **Toda UI em pt-BR.** Labels, mensagens, opções de select, placeholders.
- Logs/erros internos podem ser em inglês (são vistos só por dev).
- Comentários no código: pt-BR ou inglês, consistentes dentro do arquivo.

## Money / números

- Locale `pt-BR`, sempre com 2 casas decimais.
- PWA: `Intl.NumberFormat("pt-BR", { minimumFractionDigits: 2, maximumFractionDigits: 2 })`.
- Flutter: `NumberFormat.decimalPattern("pt_BR")` com `minimumFractionDigits: 2`.
- **Display em UI:** prefixar `R$` inline na renderização (ex.: `R$ ${formatMoney(v)}`). Não embutir `R$` dentro do formatter — facilita reuso para gráficos.
- **Formato compacto** (eixos de gráficos): `moneyK(v)` retorna `"20k"`, `"1,5k"`, ou o número formatado se `< 1000`.
- Percentual: `Intl.NumberFormat("pt-BR", { style: "percent", minimumFractionDigits: 2, maximumFractionDigits: 2 })`.

## Datas

- **Coluna A da planilha (Data, fechamento da fatura):** string `"DD/MM/YYYY"`.
- **Coluna B (Data Referência, compra):** string `"DD/MM/YYYY HH:MM"` — mas **pode vir sem a hora**: o webhook grava só a data quando não consegue extraí-la da notificação. Quem lê col B precisa aguentar as duas formas.
- O backend converte `Date` → string usando o timezone do script (Apps Script `Session.getScriptTimeZone()`).
- Frontend trata datas sempre como **string** — não converte para `Date` exceto para ordenação. Use `parseBrDate` só quando precisa comparar.
- **Qual parser usar** (Dart, `core/format/dates.dart`):
  - `parseBrDate` — col A, `"DD/MM/YYYY"` estrito. Se receber a col B com hora, lê `"YYYY HH:MM"` como ano, falha e cai no fallback **1970**: ordena certo por mês/dia e errado na fatura que cruza o ano. Não use em col B.
  - `parseBrRefDate` — col B para ordenar. Aceita com e sem hora.
  - `parseBrDateTime` — col B para **editar**. Exige a hora; o retorno epoch é sentinel de "não escolhido" no `EditDialog` (ver [pages/lancamento.md](pages/lancamento.md)).
- Display "humanizado" (Consulta header): `"06/05/2026"` → `"maio de 2026"` via `monthYearLabel`.
- Display compacto (eixo X de gráfico): `"06/05/2026"` → `"05/2026"` via `brDateToMMYYYY`.

## Naming

### Apps Script
- Funções privadas terminam com `_` (não expostas via `google.script.run` ou doGet/doPost).
- Constantes em `SCREAMING_SNAKE_CASE`.

### TypeScript / PWA
- Funções e variáveis: `camelCase`.
- Tipos e classes: `PascalCase`.
- Constantes globais: `SCREAMING_SNAKE_CASE`.
- Caminho de import absoluto via alias: `@/core/...`, `@/components/...`.

### Dart / Flutter
- Funções e variáveis: `camelCase`.
- Tipos e classes: `PascalCase`.
- Arquivos: `snake_case.dart`.
- Constantes top-level: `screamingSnakeCase` (convenção Dart) ou `kCamelCase`.

## Comentários

- **Default: zero comentários.** Identificadores bem nomeados explicam o quê.
- Comente apenas quando o **porquê** não é óbvio (workaround, invariante sutil, decisão contraintuitiva).
- Não escreva comentários que descrevem o que o código faz.
- Não cite a tarefa atual, PR, ou issue dentro do código (isso vai pra mensagem de commit / PR).
- Em arquivos de `core/`, **uma linha no topo** apontando para a spec é OK e desejável:
  ```ts
  // Spec: docs/specs/rules/diff-calculation.md
  ```

## Internal data keys

Chaves de dados internas (ex: `byOrigem["Pix (contas)"]`) usam o **valor literal da coluna**. Não inventar aliases ("pix" em vez de "Pix (contas)"). Isso evita drift entre planilha e código.

## Import paths

- PWA: aliases definidos em `tsconfig.json`/`vite.config.ts`. Use `@/...` para tudo que não é dependência npm.
- Flutter: imports relativos para arquivos próximos, `package:hook_finance/...` para módulos cross-feature.

## Implementações

- **Convention enforcement:** lint configs (`eslint`, `flutter_lints`) cobrem o estilo. Convenções aqui são as que o linter **não** captura.
