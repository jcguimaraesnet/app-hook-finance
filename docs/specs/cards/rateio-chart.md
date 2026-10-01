---
status: stable
last_updated: 2026-05-07
---

# RateioChart — Cartão por rateio (bar chart horizontal)

Bar chart horizontal mostrando o total do Cartão do mês agrupado por valor de `rateio`.

## Contexto

Aparece na aba "Pessoal" (mobile/tablet) ou ao lado da CategoriaTable (PC). Visualiza quanto cada pessoa/rateio paga em Cartão. Diferente do PersonCard, este chart soma valor **cheio** (não dividido por splitForPerson).

## Regras

### Inputs

- `rows`: `Row[]` do mês atual.

### Filtragem

- `cartao = rows.filter(r => r.origem === "Cartão")`.

### Agregação

- `byRateio[r.rateio || "(sem rateio)"] += r.valor`. (Soma cheia.)
- Resultado ordenado por valor desc.

### Labels

- `rateio === "Compartilhado"` → label `"Compartilhado"`.
- Outros → valor literal (`"Julio"`, `"Dani"`, `"Alzira"`, `"(sem rateio)"`).

### Render (Chart.js v4)

- Tipo: bar horizontal (`indexAxis: "y"`).
- Cor única por bar: `"#a07b5e"`.
- Eixo X: ticks via `moneyK(value)`.
- Eixo Y: ticks ocultos (`display: false`); grid oculto. Nome da pessoa fica **dentro** da barra (datalabel `name`).
- Datalabels:
  - `name`: `anchor: "start"`, `align: "right"`, `color: "white"`, `font: bold 11`. Render do label do dataset (`labels[index]`).
  - `value`: `anchor: "end"`, `align: "right"`, `color: "#262626"`, `font: 600 11`. Render `formatMoney(v)`.
- Tooltip: `formatMoney(parsed.x)`.
- Padding direito: 64px (espaço para o valor à direita).
- Altura: 280px (mobile/tablet), 300px (PC).
- Sem legenda.

### Comportamento Flutter

`fl_chart` não tem o sistema de plugins do Chart.js (datalabels). Implementar:

- Bar chart horizontal: `BarChart` + `BarChartGroupData`.
- Label do nome **dentro** da barra: usar `BarChartRodData.toY` + título customizado via `Stack` ou `getTitlesWidget` em `bottomTitles`.
- Valor à direita: idem, via `Padding`/`Stack` no widget pai. Se ficar muito divergente, documentar em `docs/specs/known-divergences.md` — divergência aceitável.

## Edge cases

- **Mês sem Cartão:** `byRateio = {}` → chart vazio (0 bars). UI deve renderizar mesmo (eixos visíveis).
- **`rateio` vazio:** vira label `"(sem rateio)"` com cor única igual aos outros.
- **`rateio = "Compartilhado"` é único:** mostra só uma barra `"Compartilhado"`.

## Implementações

- **PWA:** [web/src/components/RateioChart.tsx](../../../web/src/components/RateioChart.tsx)
- **Após Onda 2:** lógica de bucketing pode usar `core/rules/bucketKey.ts` se for o caso de unificar com PersonCard, mas a granularidade aqui é por **rateio puro** (não por par compartilhado/pessoal). Provavelmente fica inline.
- **Flutter:** `app/lib/widgets/rateio_chart.dart` (Onda 5, fl_chart).

## Specs relacionadas

- [../pages/consulta.md](../pages/consulta.md)
- [../rules/bucket-key.md](../rules/bucket-key.md)
- [historico-chart.md](historico-chart.md)
