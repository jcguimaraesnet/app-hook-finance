const SHEET_ID = "1IbxnOnBuhLIj5i8nqepk-Bva1IhmKalyuLXIyN56V8k";
const SHEET_NAME = "Despesas";
const FIXED_SHEET_NAME = "despesas-fixas";

const INVOICE_CLOSING_DAY = 6;
const ORIGEM = "Cartão";

// Banco emissor do cartão (col H). Substituiu o mapa de finais de cartão em
// 2026-09-12: trocar de plástico não deve exigir mudança no app.
// Spec: docs/specs/data/despesas-sheet.md
const BANCO_SANTANDER = "Santander";
const BANCO_REVOLUT = "Revolut";
const BANCOS = [BANCO_SANTANDER, BANCO_REVOLUT];
