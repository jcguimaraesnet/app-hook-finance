// Rotinas one-off. Rodar manualmente no editor do Apps Script (botão Run).
// Não são expostas via doGet/doPost.

// Migra a col H de "4 dígitos finais do cartão" para "banco emissor".
// Regra: 2236 → Revolut; qualquer outro valor não vazio e não pertencente a
// BANCOS → Santander. Valores já migrados e células vazias ficam como estão.
// Idempotente: pode rodar mais de uma vez sem efeito colateral.
// Spec: docs/specs/data/despesas-sheet.md
function migrateCardToBanco() {
  const sheet = SpreadsheetApp.openById(SHEET_ID).getSheetByName(SHEET_NAME);
  if (!sheet) throw new Error("sheet_not_found");
  const last = sheet.getLastRow();
  if (last < 2) {
    Logger.log("Planilha vazia; nada a migrar.");
    return;
  }

  const range = sheet.getRange(2, 8, last - 1, 1);
  const values = range.getValues();
  let changed = 0;
  const out = values.map((r) => {
    const raw = String(r[0] === null || r[0] === undefined ? "" : r[0]).trim();
    if (!raw || BANCOS.indexOf(raw) >= 0) return [raw];
    changed++;
    return [raw === "2236" ? BANCO_REVOLUT : BANCO_SANTANDER];
  });

  if (changed === 0) {
    Logger.log("Nada a migrar: col H já está em formato Banco.");
    return;
  }
  range.setNumberFormat("@");
  range.setValues(out);
  Logger.log("Migradas " + changed + " células da col H para Banco.");
}
