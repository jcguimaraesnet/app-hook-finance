---
status: stable
last_updated: 2026-05-08
---

# Bucket deltas — variação % vs. mês anterior

Regra que calcula a variação percentual de cada bucket (`compart`/`pessoal`/`contas`) entre o mês corrente e o mês anterior, para uma pessoa específica.

## Contexto

A página [Início](../pages/inicio.md) (Flutter, Bloom) tem um card "Comparativo vs. <mês anterior>" com 3 colunas. Cada coluna precisa do delta % daquele bucket. O cálculo só faz sentido client-side — o backend não retorna agregados pré-computados.

## Regras

### Inputs

- `currentMonth: string` no formato `"MM/YYYY"`.
- `previousMonth: string?` derivado: subtrai 1 mês de `currentMonth`. Se `currentMonth` é `"01/YYYY"`, retorna `"12/(YYYY-1)"`.
- `monthData(currentMonth).rows` e `monthData(previousMonth).rows`.
- `Person` (Júlio ou Dani).

### Cálculo dos buckets

Para cada par `(rows, person)`:

```dart
buckets = {
  'compart': Σ splitForPerson(r, person) where bucketKey(r) == 'compart',
  'pessoal': Σ splitForPerson(r, person) where bucketKey(r) == 'pessoal',
  'debito':  Σ splitForPerson(r, person) where bucketKey(r) == 'debito',
}
```

Onde:
- [bucketKey](bucket-key.md) classifica a linha em `compart`/`pessoal`/`debito`.
- [splitForPerson](split-for-person.md) retorna o valor que cabe à pessoa (cheio quando `rateio == person`, metade quando `Compartilhado`, 0 quando da outra pessoa).

### Cálculo do delta

Para cada bucket `b`:

```
prevValue = bucketsPrev[b]
curValue  = bucketsCur[b]

if (prevValue == 0) → delta = null  // não dividir por zero
else                → delta = (curValue - prevValue) / prevValue * 100
```

### Função

```dart
({double? compart, double? pessoal, double? debito}) bucketDeltas({
  required List<ExpenseRow> currentRows,
  required List<ExpenseRow> previousRows,
  required Person person,
});
```

Retorno: `null` em qualquer dos campos significa "sem comparativo" (mês anterior tinha 0).

### `previousMonthOf(string)`

```
"06/2026" → "05/2026"
"01/2026" → "12/2025"
formato inválido → null
```

## Fatias (pós-2026-10-01)

O corte é **por rateio primeiro, origem depois**:

| Fatia | Regra | Label na UI |
|---|---|---|
| `credito` | `origem === "Crédito"` E `rateio === "Compartilhado"` | **Crédito** |
| `debito` | `origem === "Débito"` E `rateio === "Compartilhado"` | **Débito** |
| `pessoal` | `rateio === <pessoa>`, em **qualquer** origem | **Pessoal** |

Valor somado é sempre `splitForPerson` (metade nas linhas `Compartilhado`, cheio nas da pessoa). As três continuam particionando o total: toda linha com `splitForPerson != 0` cai em exatamente uma.

**Antes** o corte era por origem primeiro: `Débito` ia inteiro para a fatia de débito, mesmo com rateio individual, e `pessoal` só tinha Crédito. O campo chamava-se `compart`.

**Efeito medido na fatura 06/11/2026:** nenhuma linha de Débito tinha rateio `Compartilhado` (9 Dani, 11 Julio), então a fatia Débito foi de 72% para **0%** e Pessoal de 18% para **90%** (Dani). O total não muda, só a distribuição. A fatia volta a aparecer no mês em que houver um débito dividido.

**As três fatias fecham com a tela que abrem** (conferido em 06/11/2026 para as duas pessoas): Crédito → aba Categoria (`COMPARTILHADO / 2`); Pessoal → [Despesas pessoais](../pages/detalhe.md), que passou a listar Crédito **e** Débito da pessoa; Débito → aba [Categoria](../pages/compart.md) com o tile `TOTAL DÉBITO` marcado (a tela `/debito` foi removida em 2026-10-01 — ver [../pages/debito.md](../pages/debito.md)).

## Edge cases

- **`previousMonth == null`** (primeiro mês de dados ou parse falhou): callers tratam como "sem comparativo" — cards omitem pílulas de delta.
- **`previousRows` vazio (mês anterior sem nada):** todos os deltas viram `null`.
- **`currentRows` vazio mas `previousRows` cheio:** deltas são `-100%` (queda total) — ainda válido.

## Implementações

- **Flutter:** [app/lib/core/rules/bucket_deltas.dart](../../../app/lib/core/rules/bucket_deltas.dart)
- **PWA:** N/A (PWA não exibe esse comparativo).

## Specs relacionadas

- [bucket-key.md](bucket-key.md)
- [split-for-person.md](split-for-person.md)
- [../pages/inicio.md](../pages/inicio.md) — único consumer
