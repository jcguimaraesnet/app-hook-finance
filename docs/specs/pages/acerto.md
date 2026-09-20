---
status: stable
last_updated: 2026-05-08
---

# Acerto — acerto final do mês entre Júlio e Dani

Página de fechamento mensal: quem deve a quem, quanto.

- **PWA:** 2 [AcertoCard](../cards/acerto-card.md) lado a lado (Júlio + Dani) com cartão compartilhado, cartão pessoal e Pix marcadas como `acerto`. Δ no header de cada card.
- **Flutter (Bloom):** hero gradient `violet→sky` no topo com texto fixo "Dani transfere para Júlio" + valor da diferença, botões D↔J abaixo; **uma única tabela** detalhada visível por vez (Dani por padrão), trocada via tap em D ou J.

## Contexto

No fim do mês, o casal "fecha" as contas: quem deve a quem, quanto. Esta página agrega só o que entra no acerto. Pix não-`acerto` ficam fora por padrão; o card do Júlio permite expandir e mostrar tudo (apenas como referência — não muda o cálculo).

## Regras

### Layout (PWA)

- 2 [AcertoCard](../cards/acerto-card.md) (Júlio + Dani) em grid 2-col em tablet+, empilhados em mobile.
- Não tem sub-tabs nem filtros adicionais (o filtro de mês é o StickyHeader compartilhado).

### Layout (Flutter, Bloom)

1. `ScreenHeader` com kicker "Acerto" + título "Saldo de <mês>" + `MonthSelector`.
2. **Hero card** gradient `violet→sky`:
   - Texto fixo "Dani transfere para Júlio" (kicker).
   - Valor display da diferença (`Σ buckets` da Dani — o lado que paga).
   - Botões circulares `D ↔ J` à direita; o ativo tem borda branca/violeta.
3. **Tabela única detalhada** (`PersonAcertoCard`) da pessoa selecionada (Dani por default):
   - Header com avatar inicial + nome + pílula "Diferença R$ X".
   - Linhas: `Cartão (compartilhado) | Cartão (pessoal) | Pix · Contas (cada item discriminado) | Subtotal Pix | Total Pessoal`.
   - Cada linha com `valor + %`. Última linha destacada com border-top forte.

### Source

- `useMonthData(currentMonth)` — mesma query de Consulta. Sem chamadas extras.

### Toggle do Pix do Júlio

- Estado `acertoPixJulio: boolean` no store global (Zustand, persistido). Default `false`.
- Click no header `"Débito"` do card de Júlio → `toggleAcertoPix`. Rotulado `"Pix (contas)"` até a migração de Origem (2026-09-20).
- Quando `true`: card de Júlio mostra **todas** as Pix dele do mês. Total do card cresce.
- Card de Dani **não** tem toggle equivalente.

### Δ (diff)

Mesma regra de [diff-calculation.md](../rules/diff-calculation.md). Toggle Δ é per-card (sessionStorage por pessoa). Compartilha o mesmo flag com PersonCard de Consulta.

## Edge cases

- **Mês sem nada:** ambos cards mostram totais 0 e Δ = +R$ 0,00. Ainda renderiza.
- **Mês sem Pix de nenhum:** seções Pix ocultas em ambos.
- **Mês sem Pix de Dani mas com Pix de Júlio (raro):** card de Dani sem seção Pix; card de Júlio mostra a Pix dele (acerto-only por default).
- **`currentMonth` mudou enquanto eu olhava o Acerto:** queryClient compartilha cache; o card re-renderiza automaticamente.

## Implementações

- **PWA:** [web/src/pages/AcertoPage.tsx](../../../web/src/pages/AcertoPage.tsx) (página + AcertoCard inline).
- **Após Onda 2:** sem mudanças visuais; lógica do diff/split passa a vir de `web/src/core/rules/`.
- **Flutter:** [app/lib/features/acerto/acerto_page.dart](../../../app/lib/features/acerto/acerto_page.dart) — D/J selector + tabela única (Dani default).

## Specs relacionadas

- [../cards/acerto-card.md](../cards/acerto-card.md)
- [../rules/split-for-person.md](../rules/split-for-person.md)
- [../rules/diff-calculation.md](../rules/diff-calculation.md)
- [../state/persistence.md](../state/persistence.md) — `acertoPixJulio`, toggle Δ
- [../responsive/breakpoints.md](../responsive/breakpoints.md)
