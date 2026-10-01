---
status: stable
last_updated: 2026-05-31
---

# RecentEntryRow — linha de lançamento no app

Widget compartilhado usado em todas as listas de lançamentos do Flutter app: [Início](../pages/inicio.md) (últimos 2), [Lançamento](../pages/lancamento.md) (até 100) e [Detalhe](../pages/detalhe.md) (pessoais do mês).

## Contexto

Antes de 2026-05-29, o avatar mostrava a 1ª letra da `descricao` e usava cores arbitrárias por rateio (Júlio=amber, sem relação com a identidade visual da pessoa). Isso entregava zero informação útil — a 1ª letra do estabelecimento já estava no texto ao lado, e a cor do quadradinho não ajudava a escanear a lista por rateio.

A regra atual: o avatar passa a representar o **rateio** da linha — quem paga, num símbolo + cor consistente com o resto do app.

## Anatomia

```
┌──────────────────────────────────────────────────────────────┐
│ ┌────┐                                                       │
│ │ ½  │  Mercado Extra                              R$ 89,90  │
│ └────┘  29/05/2026 · Alimentação · (1 / 3)                   │
└──────────────────────────────────────────────────────────────┘
```

## Regras

### Avatar — símbolo

| Rateio | Símbolo |
|---|---|
| `Compartilhado` | `½` |
| `Dani` | `D` |
| `Julio` | `J` |
| `Alzira` | `A` |
| Outro não-vazio | 1ª letra do rateio (uppercase) |
| Vazio | `?` |

### Avatar — cor (fundo e texto)

A cor `tone` é aplicada como `tone.withValues(alpha: 0.13)` no fundo e como cor sólida no texto.

| Rateio | `tone` |
|---|---|
| `Compartilhado` | `BloomColors.neutral` (cinza neutro sem viés violeta) |
| `Dani` | `BloomColors.violet` (= `forPerson(dani)`) |
| `Julio` | `BloomColors.mint` (= `forPerson(julio)`) |
| Outro não-vazio (ex.: `Alzira`) | `BloomColors.amber` |
| Vazio | `BloomColors.neutral` |

A cor `neutral` (`#8E8E96`) é usada em vez de `muted` (`#7B7AA8`) propositalmente: `muted` tem viés violeta e ficava visualmente parecido com o lilás da Dani na opacidade 0.13. `neutral` é um cinza puro.

Cores de `Dani`/`Julio` derivam de `BloomColors.forPerson()` — invertidas em 2026-05-29 (ver [../pages/inicio.md](../pages/inicio.md)).

### Data na linha da descrição (pós-2026-10-01)

A data saiu da 2ª linha e passou a ficar **à direita da descrição**, na 1ª linha, no formato **`DD/MM`** e com o mesmo tipo da meta (`mono`, 10px, `muted`). A meta tinha data, categoria e parcela disputando uma linha de 10px.

- Origem do valor: `_stripTime(entry.dataRef)` se `dataRef` não-vazia, senão `entry.data`. Hora é **sempre** removida (corta no primeiro espaço). Depois `_diaMes` corta o ano: `"30/09/2026 22:16"` → `"30/09"`. Formato inesperado passa intacto.
- Alinhamento pela **baseline** com a descrição, que é 12,5px — os tops não coincidem, e é esperado.
- A descrição vira `Flexible` para a data nunca ser empurrada fora da linha.

### Linha de metadados (2ª linha)

Formato padrão: `cat [· (X / Y)]`

- `cat` = `entry.categoria` se não-vazia, senão `—`.
- `(X / Y)` aparece **apenas** quando `entry.parcela` está preenchida e parseia como `X/Y`. Espaços ao redor de `/` são obrigatórios no display (`"(1 / 3)"`, não `"(1/3)"`). Quando `parcela` é legado sem `/` (ex.: `"3"`), o sufixo não aparece.

Tipo: `BloomTypography.mono`, `fontSize: 10`, `color: BloomColors.muted`.

### Flag `hideCategory` (telas com largura crítica)

Quando o widget é instanciado com `hideCategory: true`, a categoria é omitida e a 2ª linha vira só `(X / Y)` — o `· ` da frente do sufixo é removido, senão sobraria um separador solto. **Sem parcela, a 2ª linha não é renderizada** (não fica um espaço em branco). Usado em telas onde a categoria não acrescenta info útil — ex.: [Detalhe](../pages/detalhe.md), onde a lista é estreita demais em mobile pra incluir categoria sem estourar o ellipsis.

Default: `hideCategory: false`. Usado por [Início](../pages/inicio.md) e [Lançamento](../pages/lancamento.md) — onde a categoria é relevante pra distinguir os lançamentos.

### highlightMissing (override)

Quando o widget é instanciado com `highlightMissing: true` E `entry.categoria` ou `entry.rateio` está vazio:

- `tone` vira `BloomColors.bad` (sobrepõe a tabela acima).
- Cor da descrição vira `BloomColors.bad` (em vez de `BloomColors.ink`).

Usado na lista de Lançamentos para destacar entries do webhook que ainda não foram classificadas. Início e Detalhe não usam essa flag.

## Edge cases

- `descricao` vazia → texto principal mostra `—`.
- `rateio` vazio + `highlightMissing: false` → avatar `?` em tom `muted`.
- `parcela = "1/1"` → ainda mostra `(1 / 1)` na linha? **Não:** spec emite só quando o formato parseia E `Y > 0`. `"1/1"` parseia e tem `Y=1` — emite `(1 / 1)`. Isso é intencional (raro na prática) e consistente com a regra "se tem dado, mostra".
- `onTap == null` (Início, Detalhe) → widget não envolve em `InkWell`, não mostra `chevron_right`.

## Implementações

- **Flutter:** [app/lib/widgets/bloom/recent_entry_row.dart](../../../app/lib/widgets/bloom/recent_entry_row.dart).
- **PWA:** sem equivalente — a PWA React congelada usa pills em vez de avatar (ver [../pages/lancamento.md](../pages/lancamento.md), seção "Lista de entries (PWA legada)").

## Specs relacionadas

- [../pages/inicio.md](../pages/inicio.md) — cores por pessoa.
- [../pages/lancamento.md](../pages/lancamento.md) — uso na lista editável.
- [../pages/detalhe.md](../pages/detalhe.md) — uso na lista de despesas pessoais.
- [../rules/parcela-format.md](../rules/parcela-format.md) — formato `X/Y`.
