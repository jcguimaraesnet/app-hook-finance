---
status: stable
last_updated: 2026-09-20
---

# categoriaRowsForMonth

Linhas de Crédito de uma categoria no mês, e os dois totais que a tabela do [Compart](../pages/compart.md) exibe para ela.

## Contexto

A tabela do Compart agrupa por categoria; a tela de [Categoria](../pages/categoria.md) detalha uma delas. Se cada lado montasse o próprio filtro, o detalhamento poderia não somar o número clicado — o mesmo risco que motivou [debito-rows.md](debito-rows.md).

Dois detalhes fáceis de errar sozinho: o agrupamento só considera `origem === "Crédito"`, e a categoria vazia é exibida como `—`, que é o nome que chega na rota.

## Regras

1. `categoriaLabel(row)` → `row.categoria` ou `"—"` quando vazia. **Usada pelos dois lados**: pelo Compart ao agrupar e pela tela ao filtrar.
2. `categoriaRowsForMonth(rows, categoria)` → linhas com `origem === "Crédito"` **e** `categoriaLabel(row) === categoria`. Preserva a ordem de entrada.
3. `categoriaTotais(linhas)` → `{ total, compart }`:
   - `total = Σ valor` (cheio).
   - `compart = Σ valor/2` apenas das linhas com `rateio === "Metade"`.

**Invariante de reconciliação** (garantida por teste): para toda categoria da tabela, `categoriaTotais(categoriaRowsForMonth(rows, cat)).total` é igual ao valor que o Compart soma para `cat`.

## Edge cases

- **`rows` vazio:** retorna `[]` e totais zerados.
- **Categoria vazia:** acessível pelo nome `—`; nenhuma linha se perde.
- **Linhas de Débito:** ficam de fora, mesmo com a mesma categoria — o Compart é de Cartão.
- **Sem linhas `Metade`:** `compart = 0`, `total` continua cheio.
- **`valor` negativo (estorno):** entra normalmente nos dois totais.

## Implementações

- **Flutter:** [app/lib/core/rules/categoria_rows.dart](../../../app/lib/core/rules/categoria_rows.dart)

## Specs relacionadas

- [../pages/compart.md](../pages/compart.md) — tabela de origem
- [../pages/categoria.md](../pages/categoria.md) — a tela que consome
- [split-for-person.md](split-for-person.md)
