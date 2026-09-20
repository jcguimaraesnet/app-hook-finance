// Classifica Categoria e Rateio de uma compra nova com base no histórico
// de compras de cartão já classificadas. Usa similaridade Jaccard sobre
// tokens normalizados.

const CLASSIFY_THRESHOLD = 0.4;

const CLASSIFY_STOP_WORDS = new Set([
  "LJ",
  "LOJA",
  "FILIAL",
  "BR",
  "COM",
  "LTDA",
  "SA",
  "ME",
  "EPP",
  "S",
  "A",
]);

function classifyFromHistory_(sheet, descricao) {
  const empty = { categoria: "", rateio: "" };
  if (!descricao) return empty;
  const last = sheet.getLastRow();
  if (last < 2) return empty;

  const newTokens = new Set(tokenizeForClassify_(descricao));
  if (newTokens.size === 0) return empty;

  const data = sheet.getRange(2, 1, last - 1, 7).getValues();
  let bestScore = 0;
  let best = null;
  for (const r of data) {
    // normalizeOrigem_ para não perder o histórico entre o deploy e a migração
    // da col E: linha ainda em "Cartão" precisa continuar servindo de base.
    if (normalizeOrigem_(r[4]) !== ORIGEM) continue;
    const cat = String(r[5] || "").trim();
    const rat = String(r[6] || "").trim();
    if (!cat && !rat) continue;
    const tokens = new Set(tokenizeForClassify_(r[2]));
    const score = jaccard_(newTokens, tokens);
    if (score > bestScore) {
      bestScore = score;
      best = { categoria: cat, rateio: rat };
    }
  }
  return bestScore >= CLASSIFY_THRESHOLD ? best : empty;
}

function normalizeForClassify_(text) {
  return String(text || "")
    .toUpperCase()
    .normalize("NFD")
    .replace(/[̀-ͯ]/g, "")
    .replace(/[^A-Z0-9\s]/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}

function tokenizeForClassify_(text) {
  return normalizeForClassify_(text)
    .split(" ")
    .filter((t) => t.length > 1 && !CLASSIFY_STOP_WORDS.has(t));
}

function jaccard_(setA, setB) {
  if (setA.size === 0 || setB.size === 0) return 0;
  let inter = 0;
  setA.forEach((t) => {
    if (setB.has(t)) inter++;
  });
  return inter / (setA.size + setB.size - inter);
}
