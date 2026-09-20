---
status: stable
last_updated: 2026-09-20
---

# Despesas fixas — editar o template da Nova fatura

Tela de configuração que lista e edita a aba `despesas-fixas` ([../data/despesas-fixas-sheet.md](../data/despesas-fixas-sheet.md)) — o template que a Nova fatura insere no topo de `Despesas` a cada fatura nova.

Só existe no Flutter (Bloom). Acesso pelo menu hambúrguer da [Início](inicio.md), acima de Configurações.

## Contexto

Até 2026-09-20 a aba só era editável à mão no Google Sheets — o spec do schema dizia isso explicitamente. Na prática, mudar o valor do condomínio exigia abrir a planilha no navegador.

O risco que a tela reduz: uma linha malformada faz `loadFixedExpenses_` lançar, o gatilho responde `fixed_expenses_failed` e **a primeira compra da fatura não entra** até alguém corrigir. Antes só dava para descobrir isso quando a fatura travava.

## Regras

### Rota

`/despesas-fixas`, empilhada sobre a Início (tem back).

### Inputs

`fixedExpenses` (GET). Nenhum outro endpoint na carga. Ver [../api/endpoints.md](../api/endpoints.md).

### Tiles

| Tile | Valor |
|---|---|
| **TOTAL MENSAL** | `Σ valor` de todas as linhas. É quanto a Nova fatura injeta por mês. |
| **LINHAS** | Quantidade de linhas não-vazias. |

### Lista

Uma linha por registro, **na ordem da aba** — que é a ordem em que entram na fatura. Cada linha mostra:

- Quadrado com o **dia** (col A).
- Descrição; abaixo, `rateio · origem` e `· acerto` quando `acerto = "Sim"`.
- Valor à direita, com chevron.

**Linha inválida** (campo `invalid` preenchido pelo backend) renderiza em vermelho e troca a meta-linha pelo motivo (ex.: `dia inválido (32)`). Um aviso no topo conta quantas são e diz que elas **travam a criação da próxima fatura** — é a informação que o usuário precisa para agir, não um detalhe técnico.

### Edição

Tap abre o modal; o botão **Nova despesa fixa** abre o mesmo modal vazio.

Campos: Dia (1–31), Valor, Descrição, Categoria, Origem (`Crédito`|`Débito`), Rateio, e um switch **Entra no acerto** (grava `"Sim"` na col G).

- **Rateio não aceita vazio** aqui, diferente da col G da aba Despesas: a linha vira lançamento de verdade na fatura e ficaria sem dono. O dropdown só oferece `Julio`, `Dani`, `Metade`, `Alzira`.
- Defaults do modal de criação: Categoria `Contas`, Origem `Débito`, Rateio `Metade` — o perfil das 20 linhas existentes.
- Validação local dá a mensagem imediata; a do servidor é a autoritativa. Quando o backend recusa, a tela mostra o campo `detail` (ex.: `dia inválido (32)`) e não o código `invalid_fields`.
- Excluir fica no header do modal, como em [lancamento.md](lancamento.md), e só aparece ao editar.

Salvar ou excluir invalida `fixedExpensesProvider`.

### Loading / vazio

- Loading: spinner no card da lista.
- Sem linhas: `"Nenhuma despesa fixa cadastrada."` (a aba nunca deveria ficar assim — `loadFixedExpenses_` lança em aba vazia).
- Erro de carga: aviso vermelho com a mensagem, no lugar dos tiles.

## Edge cases

- **Linha inválida na aba:** aparece na lista, em vermelho, editável. A tela **não** pode quebrar junto com a linha — seria a única forma de consertá-la pelo app.
- **`valor = 0`:** legítimo (linha placeholder). Conta como conteúdo, não como linha em branco.
- **Ordem:** criar insere **no fim** da aba. Reordenar não é suportado pela tela; continua sendo edição manual na planilha.
- **Concorrência:** sem `LockService` no backend — aba de configuração, um usuário só.

## Implementações

- **Flutter:** [app/lib/features/despesas_fixas/despesas_fixas_page.dart](../../../app/lib/features/despesas_fixas/despesas_fixas_page.dart) e [fixed_expense_dialog.dart](../../../app/lib/features/despesas_fixas/fixed_expense_dialog.dart).
- **Backend:** `getFixedExpenses` / `addFixedExpense` / `updateFixedExpense` / `deleteFixedExpense` em [apps-script/webhook/FixedExpenses.gs](../../../apps-script/webhook/FixedExpenses.gs).
- Rota em [app/lib/app.dart](../../../app/lib/app.dart); entrada de menu em [inicio.md](inicio.md).

## Specs relacionadas

- [../data/despesas-fixas-sheet.md](../data/despesas-fixas-sheet.md) — schema das 7 colunas
- [../rules/fixed-expenses.md](../rules/fixed-expenses.md) — como o template vira lançamento
- [../rules/new-invoice.md](../rules/new-invoice.md) — o gatilho que consome a aba
- [../api/endpoints.md](../api/endpoints.md) — contrato do CRUD
