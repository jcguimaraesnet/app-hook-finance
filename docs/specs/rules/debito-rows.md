---
status: stable
last_updated: 2026-09-20
---

# debitoRowsForPerson

Dadas as linhas do mês e uma pessoa, retorna as linhas que compõem o bucket **Débito** daquela pessoa — as mesmas que o card Comparativo da [Início](../pages/inicio.md) soma na coluna "Débito".

## Contexto

O bucket Débito aparece como um número agregado em três lugares (donut do hero, coluna do Comparativo e a página [Débito](../pages/debito.md)). O número é fácil de reproduzir errado porque envolve **dois** filtros que não são óbvios juntos: `origem === "Débito"` **e** rateio que toca a pessoa. Quem lista as linhas sem aplicar o segundo filtro mostra uma lista que não fecha com o total exibido — foi exatamente o risco ao tornar a coluna clicável.

Esta função é a fonte única: `bucketsForPerson(...).contas` e a lista da página Contas derivam dela, então **reconciliam por construção**.

## Regras

`debitoRowsForPerson(rows, person) → Row[]`:

1. Mantém a linha se `row.origem === "Débito"`. Antes da migração de Origem (2026-09-20) o filtro era `origem !== "Cartão"`, cobrindo `Pix (contas)`, `Contas`, `Empregados` e `Pessoal` — ver [../data/despesas-sheet.md](../data/despesas-sheet.md).
2. **E** se `splitForPerson(row, person) !== 0` — ver [split-for-person.md](split-for-person.md).
3. Preserva a ordem de entrada. Não ordena, não deduplica, não soma.

**Invariante de reconciliação** (garantida por teste):

```
Σ splitForPerson(r, person) para r em debitoRowsForPerson(rows, person)
  === bucketsForPerson(rows, person).debito
```

Qualquer mudança em [bucket-deltas.md](bucket-deltas.md) que altere o bucket `debito` tem que alterar esta regra junto, ou o teste de reconciliação quebra.

## Edge cases

- **`rows` vazio:** retorna `[]`.
- **`rateio` vazio (`""`) numa linha de Débito:** fica de fora para qualquer pessoa — `splitForPerson` retorna 0. A linha existe na planilha e não aparece para ninguém; é uma linha mal preenchida, e o total do card também a ignora.
- **`rateio = "Alzira"`** com `person = Julio|Dani`: fica de fora, pelo mesmo motivo.
- **`rateio = "Metade"`:** entra para Júlio e para Dani, com `valor / 2` cada. A linha aparece nas duas listas — correto, a despesa é das duas pessoas.
- **`valor` negativo (estorno):** entra normalmente; `splitForPerson` só retorna 0 quando o rateio não casa, não por causa do sinal.
- **`valor = 0`:** fica de fora (`splitForPerson` retorna 0). Degenerado, sem efeito no total.

## Implementações

- **Flutter:** [app/lib/core/rules/debito_rows.dart](../../../app/lib/core/rules/debito_rows.dart)
- **PWA legada:** não existe (a IA legada não tinha essa tela). Não portar — `web/` está congelado.

## Specs relacionadas

- [split-for-person.md](split-for-person.md) — o filtro de rateio
- [bucket-deltas.md](bucket-deltas.md) — `bucketsForPerson`, que produz o número exibido
- [../pages/debito.md](../pages/debito.md) — a página que consome a lista
- [../pages/inicio.md](../pages/inicio.md) — o card de onde se navega
