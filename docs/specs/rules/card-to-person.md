---
status: removed
last_updated: 2026-09-12
---

# Card to person — mapping de finais de cartão (REMOVIDO)

> **Removido em 2026-09-12.** A coluna H deixou de guardar os 4 dígitos finais do cartão e passou a guardar o **banco emissor** (`Santander` | `Revolut`). Ver [../data/despesas-sheet.md](../data/despesas-sheet.md) e [webhook-parser.md](webhook-parser.md).

## Por que foi removido

Cada troca de cartão (vencimento, fraude, upgrade) exigia atualizar a constante `CARDS` no backend e redeployar. O mapping nunca foi usado por nenhuma regra de UI ou de cálculo — era só metadata. O que interessa na prática é a **origem** do lançamento (qual banco), que é estável e não muda quando o plástico muda.

## O que substituiu

- Col H (`Banco`): enum `Santander` | `Revolut` | `""`.
- Webhook: o padrão da notificação define o banco (`PURCHASE_RE` → Santander; `NEW_APP_VALUE_RE` → Revolut). O final do cartão presente no texto do Santander é ignorado.
- `addEntry` / `updateEntry`: campo `banco` (opcional, validado contra o enum).
- Migração dos valores legados: `migrateCardToBanco()` em `apps-script/shared/Maintenance.gs` (`2236` → `Revolut`; qualquer outro numérico → `Santander`).

## Histórico (para referência)

Mapping que existia até a remoção:

```
1018, 9727, 2236 → Julio
4750, 0784       → Dani
```

Este arquivo fica como tombstone para que links antigos não quebrem. Não reintroduzir sem revisar a decisão acima.
