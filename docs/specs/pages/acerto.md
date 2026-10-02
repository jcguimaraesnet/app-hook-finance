---
status: stable
last_updated: 2026-10-01
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
   - Linhas: `Crédito (compartilhado) | Crédito (pessoal) | Subtotal crédito | Débito (compartilhado) | Débito (outros) | Débito (pessoal) | Total Pessoal`.
   - Cada linha com `valor + %`. Última linha destacada com border-top forte.

### Source

- `useMonthData(currentMonth)` — mesma query de Consulta. Sem chamadas extras.

### Linhas agrupadas

**Três blocos simétricos** (pós-2026-10-02), cada um com suas linhas agrupadoras expansíveis e fechado por uma **faixa de subtotal**:

| Bloco | Linhas | Filhos | Subtotal |
|---|---|---|---|
| Reembolsos | `Reembolsos` | lançamentos | `Subtotal reembolsos` |
| Crédito | `Crédito (compartilhado)` · `Crédito (pessoal)` | **categorias**, maior primeiro | `Subtotal crédito` |
| Débito | `Débito (compartilhado)` · `Débito (pessoal)` | lançamentos | `Subtotal débito` |

`Total Pessoal` no rodapé = os três subtotais. Expandir só mostra ou esconde; os filhos **sempre somam** o subtotal que abre o grupo.

A faixa de subtotal é uma barra de fundo `track` de ponta a ponta, mais alta que uma linha comum, com filete em cima e embaixo: é o que divide a tabela em blocos à primeira vista. Um filete fino sozinho se perdia entre os filhos indentados logo acima dela.

#### Reembolsos (primeiro bloco)

- Lançamentos do acerto da pessoa cuja col J (`Para reembolsar`) traz o nome da **outra** pessoa — o que ela deve devolver. No card do Júlio são as linhas marcadas `Dani`, e vice-versa.
- **Saem dos outros quatro grupos**: a mesma despesa não pode ser contada em dois lugares. O total da pessoa não muda — é uma regrouping.
- Valor por `splitForPerson`, como no resto do card: linha `Compartilhado` entra pela metade.
- Linha marcada com o nome da **própria** pessoa não é reembolso dela: fica onde estava.
- Enquanto a planilha tiver o valor legado `"Sim"` na col J, nenhuma linha casa com o filtro e o bloco aparece zerado — ver [../data/despesas-sheet.md](../data/despesas-sheet.md#mudança-de-semântica-da-col-j-2026-10-02). Quem marca é o modal de [despesa fixa](despesas-fixas.md).

#### Crédito e débito

**As duas de crédito agrupam por categoria**, as duas de débito listam lançamento. O corte é o que cada origem é: crédito é fatura de cartão, compras miúdas onde a lista não responde o que se pergunta olhando o acerto — em que foi o dinheiro; débito são contas com nome próprio (Condomínio, Diarista, Dízimo), que se identificam uma a uma.

Regra das categorias: `acertoCreditoCategorias(rows, person, {required compartilhado})` em [app/lib/core/rules/acerto_total.dart](../../../app/lib/core/rules/acerto_total.dart). `compartilhado: true` filtra rateio `Compartilhado` (metade da pessoa); `false`, o rateio da própria pessoa (valor cheio) — `splitForPerson` já faz a distinção, então as duas fecham com o subtotal. Categoria vazia vira `—` (mesma label da tabela de [Categoria](compart.md)).

- Na linha de débito dividido os filhos mostram a parte da pessoa — senão não somariam o subtotal do cabeçalho.
- A coluna `Acerto` (col J) **não filtra** o que entra no acerto desde 2026-10-01; desde 2026-10-02 ela decide só o bloco Reembolsos.
- Expandir só mostra ou esconde. Até 2026-10-01 o toggle era exclusivo do Júlio e mudava a **composição** — incluía lançamentos fora do acerto e o subtotal mudava junto, o que tornava o número da tela ambíguo. `acertoPixJulioProvider` foi removido.
- O número grande do topo e o `Total Pessoal` do card são o **mesmo valor** e vêm os dois de `acertoBreakdown`. Já divergiram por estarem calculados em dois lugares.

#### Histórico dos agrupamentos de débito

De 2026-10-01 a 2026-10-02 o débito da pessoa foi exibido em **dois** grupos, partidos pela categoria: `Débito (outros)` (categoria ≠ `Pessoal`) e `Débito (pessoal)`. Voltaram a ser um só para a tabela ficar simétrica com as duas linhas de crédito. O corte por categoria sobreviveu onde muda número — na pílula Diferença, via `debitoParaDiferenca`.

### Δ (diff)

Pílula "Diferença R$ X" no header de cada card. Desde 2026-10-01 é simplesmente a **diferença entre as duas linhas `Débito (outros)`** da tela — a do card aberto menos a da outra pessoa, em módulo. Regra em [diff-calculation.md](../rules/diff-calculation.md).

Antes somava todo o Débito que tocava cada pessoa, incluindo a categoria `Pessoal`, e o número não batia com nenhuma linha visível. Na fatura 06/11/2026 foi de R$ 194,42 para R$ 155,58. Toggle Δ é per-card (sessionStorage por pessoa). Compartilha o mesmo flag com PersonCard de Consulta.

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
