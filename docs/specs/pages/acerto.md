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

**Todas as cinco linhas são expansíveis** (pós-2026-10-02), nos dois cards. Expandir só mostra ou esconde; os filhos **sempre somam o subtotal** que abre o grupo.

| Linha | Filhos |
|---|---|
| `Crédito (compartilhado)` | **categorias**, maior primeiro |
| `Crédito (pessoal)` | **categorias**, maior primeiro |
| `Débito (compartilhado)` | lançamentos, pela metade |
| `Débito (outros)` | lançamentos, valor cheio |
| `Débito (pessoal)` | lançamentos, valor cheio |

Logo abaixo das duas de crédito vem a linha **`Subtotal crédito`** = `creditoCompart + creditoPessoal` (getter `AcertoBreakdown.credito`). Não é expansível: fecha o bloco de crédito. Peso visual entre o de uma linha agrupadora e o do `Total Pessoal` do rodapé, com filete acima — é o que a distingue dos filhos indentados logo acima dela. O débito não tem subtotal equivalente (não foi pedido).

**As duas de crédito agrupam por categoria**, as três de débito listam lançamento. O corte é o que cada origem é: crédito é fatura de cartão, compras miúdas onde a lista não responde o que se pergunta olhando o acerto — em que foi o dinheiro; débito são contas com nome próprio (Condomínio, Diarista, Dízimo), que se identificam uma a uma.

Regra: `acertoCreditoCategorias(rows, person, {required compartilhado})` em [app/lib/core/rules/acerto_total.dart](../../../app/lib/core/rules/acerto_total.dart). `compartilhado: true` filtra rateio `Compartilhado` (metade da pessoa); `false`, o rateio da própria pessoa (valor cheio) — `splitForPerson` já faz a distinção, então as duas fecham com o subtotal. Categoria vazia vira `—` (mesma label da tabela de [Categoria](compart.md)).

Conferido em 06/11/2026 (card da Dani): compartilhado Casa 725,71 + Mercado 570,68 + Viagem 375,00 + Transporte 82,41 + Fernanda 12,91 = 1.766,70; pessoal Pessoal 1.765,89 + Farmacia 159,29 = 1.925,18.

#### Os três grupos de débito

| Linha | Filtro | Valor somado |
|---|---|---|
| `Débito (compartilhado)` | `origem === "Débito"` E `rateio === "Compartilhado"` | `splitForPerson` (metade) |
| `Débito (outros)` | `origem === "Débito"` E `rateio === <pessoa>` E `categoria !== "Pessoal"` | valor cheio |
| `Débito (pessoal)` | `origem === "Débito"` E `rateio === <pessoa>` E `categoria === "Pessoal"` | valor cheio |

- A comparação de categoria é normalizada (`trim().toLowerCase()`): a col F é texto livre.
- Na linha compartilhada os filhos mostram a parte da pessoa, para somarem o subtotal do cabeçalho; nas outras duas, o valor cheio.
- Nas linhas de débito dividido os filhos mostram a parte da pessoa — senão não somariam o subtotal do cabeçalho.
- `outros` + `pessoal` é exatamente o conjunto da antiga linha única `Débito (pessoal)`. A divisão é **de apresentação**: o total transferido não muda (teste em `acerto_total_test.dart`). Motivo: contas de casa que a pessoa paga sozinha (Condomínio, Gás, Diarista) não são gasto pessoal dela e misturavam-se com Dízimo/Previdência.
- A coluna `Acerto` (col J) **não filtra nada** aqui desde 2026-10-01. Antes só `"Sim"` entrava, e o card mostrava uma despesa onde havia cinco.
- Expandir **só mostra ou esconde** os lançamentos. Até 2026-10-01 o toggle era exclusivo do Júlio e mudava a **composição** — incluía linhas fora do acerto e o subtotal mudava junto, o que tornava o número da tela ambíguo. `acertoPixJulioProvider` foi removido.
- O número grande do topo e o `Total Pessoal` do card são o **mesmo valor** e vêm os dois de `acertoBreakdown` ([app/lib/core/rules/acerto_total.dart](../../../app/lib/core/rules/acerto_total.dart)). Já divergiram por estarem calculados em dois lugares.

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
