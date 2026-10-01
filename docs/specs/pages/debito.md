---
status: stable
last_updated: 2026-09-20
---

# Débito — REMOVIDA em 2026-10-01

A tela `/debito` saiu. A coluna **Débito** do Comparativo da [Início](inicio.md) passou a abrir a aba [Categoria](compart.md) com o tile `TOTAL DÉBITO` marcado — mesmo fluxo da coluna Crédito.

Com a tabela de Categoria listando só o que é dividido e recortando pela origem marcada, aquela tela passou a mostrar a mesma informação com um caminho a menos. Saíram junto: `features/debito/`, `core/rules/debito_rows.dart` e seus testes.

Histórico: existiu entre 2026-09-19 e 2026-10-01. Nasceu como drill-down de "todo o débito que toca a pessoa" e, depois que as fatias passaram a cortar por rateio, foi alinhada para listar só o débito compartilhado.
