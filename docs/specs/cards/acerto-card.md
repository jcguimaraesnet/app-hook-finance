---
status: stable
last_updated: 2026-05-07
---

# AcertoCard — card de pessoa em Acerto Final

> **Congelado (PWA legada).** Descreve a PWA React em `web/`, que não é mais deployada. Os nomes de origem citados aqui (`Cartão`, `Pix (contas)`, `Empregados`) são o enum **pré-2026-09-20**; a col E hoje é `Crédito` | `Débito` — ver [../data/despesas-sheet.md](../data/despesas-sheet.md).

Card que mostra, para uma pessoa, o que entra no acerto do mês: Cartão (compartilhado), Cartão (pessoal), e Pix (contas) marcadas como `acerto = "Sim"`. Inclui Δ no header — mesma regra do PersonCard.

## Contexto

Página dedicada (Acerto). Mostra os pares (Júlio + Dani) lado a lado. Diferente do PersonCard, este card pode **expandir** a seção de Pix (Júlio só) para mostrar todas as Pix da pessoa — útil para conferir o que está fora do acerto.

## Regras

### Inputs

- `person`: `"Julio" | "Dani"`.
- `rows`: `Row[]` do mês atual.
- `loading`: bool do parent.

### Cartão (compartilhado)

- Filtra `r.origem === "Cartão"` E `r.rateio === "Metade"`.
- Soma `splitForPerson(r, person)` para cada linha.
- Resultado: linha "Cartão (compartilhado)" com esse total.

### Cartão (pessoal)

- Filtra `r.origem === "Cartão"` E `r.rateio ∈ {"Julio", "Dani"}`.
- Soma `splitForPerson(r, person)` para cada linha.
  - Note que `splitForPerson` só retorna não-zero quando `rateio === person`. As linhas com `rateio = outro` somam 0 — mas a iteração inclui ambas para manter a regra explícita.
- Resultado: linha "Cartão (pessoal)" com esse total.

### Seção Pix (contas)

Computa duas listas:

- `pixAllForPerson` = linhas com `origem === "Pix (contas)"` E `rateio === person`.
- `pixAcerto` = subset onde `acerto === "Sim"`.

`expanded`:

- Para Júlio: `expanded = acertoPixJulio` (toggle no store global). Default false.
- Para Dani: sempre `false`.

`pixVisible = expanded ? pixAllForPerson : pixAcerto`.

`showSection`:

- Júlio: `pixAllForPerson.length > 0` (pra dar alvo de clique mesmo se nenhum acerto).
- Dani: `pixAcerto.length > 0`.

Quando visível:

- Header da seção: `"Pix (contas)"`. No card de Júlio, é clicável (toggleAcertoPix do store).
- Linhas: cada item de `pixVisible` com descrição (truncada) + valor.

### Total Pessoal

```
total = cartaoCompart + cartaoPessoal + Σ valor de pixVisible
```

Note que somar `pixVisible` (não `pixAcerto`) tem efeito quando Júlio está expandido — total cresce ao incluir Pix não-acerto.

### Header — diff

Mesma regra de [PersonCard](person-card.md). `diff = diffCalculation(rows, person)` independente de qualquer filtro de Pix neste card. Razão: o diff precisa bater entre Acerto e Consulta — ver [../rules/diff-calculation.md](../rules/diff-calculation.md).

Toggle Δ vive em `sessionStorage` (compartilhado com PersonCard) — ver [../state/persistence.md](../state/persistence.md).

## Edge cases

- **Mês sem Cartão:** linhas "Cartão (compartilhado)" e "Cartão (pessoal)" mostram 0,00.
- **Mês sem Pix da pessoa:** seção Pix oculta inteira (Dani sempre, Júlio só se também não tiver `pixAllForPerson`).
- **Júlio expandido com nenhum Pix:** `pixVisible = []`, mas `showSection = true` pelo `pixAllForPerson > 0`. Não é o caso (`expanded` só vira true via clique no header, e clicar no header só faz sentido se já há Pix). Defensivo.
- **Loading:** mostra 3 skeleton lines em lugar da tabela.

## Implementações

- **PWA atual:** [web/src/pages/AcertoPage.tsx:36-200](../../../web/src/pages/AcertoPage.tsx) (componente `AcertoCard` definido inline).
- **Após Onda 2:** mesmo arquivo, usando `splitForPerson`, `diffCalculation` de `web/src/core/`. (Considerar extrair `AcertoCard` para `web/src/components/AcertoCard.tsx` se ficar grande — não obrigatório agora.)
- **Flutter:** `app/lib/widgets/acerto_card.dart` (Onda 5).

## Specs relacionadas

- [person-card.md](person-card.md) — variante em Consulta
- [../rules/split-for-person.md](../rules/split-for-person.md)
- [../rules/diff-calculation.md](../rules/diff-calculation.md)
- [../pages/acerto.md](../pages/acerto.md)
- [../state/persistence.md](../state/persistence.md) — `acertoPixJulio`, toggle Δ
