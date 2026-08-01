function jsonResponse_(obj) {
  return ContentService.createTextOutput(JSON.stringify(obj)).setMimeType(
    ContentService.MimeType.JSON,
  );
}

function parseBrazilNumber_(s) {
  const n = parseFloat(s.replace(/\./g, "").replace(",", "."));
  return isNaN(n) ? "" : n;
}

function normalizeDate_(d) {
  const parts = d.split("/");
  if (parts.length === 3 && parts[2].length === 2) parts[2] = "20" + parts[2];
  return parts.join("/");
}

function formatBrDate_(v) {
  if (v instanceof Date) {
    return Utilities.formatDate(v, Session.getScriptTimeZone(), "dd/MM/yyyy");
  }
  return String(v).trim();
}

function parseBrDate_(s) {
  const parts = String(s || "").split("/");
  if (parts.length !== 3) return new Date(0);
  const d = parseInt(parts[0], 10) || 1;
  const m = parseInt(parts[1], 10) || 1;
  const y = parseInt(parts[2], 10) || 1970;
  return new Date(y, m - 1, d);
}

function insertRowsAtTop_(sheet, rows) {
  if (!rows || rows.length === 0) return;
  sheet.insertRowsBefore(2, rows.length);
  sheet.getRange(2, 1, rows.length, rows[0].length).setValues(rows);
}

function nextInvoiceClosingDate_() {
  const tz = Session.getScriptTimeZone();
  const now = new Date();
  const year = parseInt(Utilities.formatDate(now, tz, "yyyy"), 10);
  const month = parseInt(Utilities.formatDate(now, tz, "MM"), 10);
  let nextMonth = month + 1;
  let nextYear = year;
  if (nextMonth > 12) {
    nextMonth = 1;
    nextYear += 1;
  }
  const dd = ("0" + INVOICE_CLOSING_DAY).slice(-2);
  const mm = ("0" + nextMonth).slice(-2);
  return dd + "/" + mm + "/" + nextYear;
}

// Retorna a data de fechamento mais recente registrada na col A (string "DD/MM/YYYY"),
// ou null se a planilha só tiver headers. Usado pelo webhook para alinhar novos
// lançamentos com a última fatura conhecida (criada por Nova fatura ou prévia),
// em vez de computar a partir de hoje.
// Spec: docs/specs/api/webhook.md, docs/specs/rules/invoice-closing-date.md
function latestInvoiceClosingInSheet_(sheet) {
  const last = sheet.getLastRow();
  if (last < 2) return null;
  const colA = sheet.getRange(2, 1, last - 1, 1).getValues();
  let bestDate = null;
  let bestStr = null;
  for (let i = 0; i < colA.length; i++) {
    const str = formatBrDate_(colA[i][0]);
    if (!str) continue;
    const d = parseBrDate_(str);
    if (bestDate === null || d > bestDate) {
      bestDate = d;
      bestStr = str;
    }
  }
  return bestStr;
}

// Fatura "nova" para o gatilho manual (Nova fatura). Ancorada na fatura mais
// recente JÁ registrada na planilha (maior data da col A) + 1 mês — NÃO em `now`.
// Mesma filosofia do webhook (latestInvoiceClosingInSheet_): "Nova fatura" cria
// sempre a fatura imediatamente seguinte à última que existe na base, seja qual
// for a data de hoje. Se a planilha só tem headers (primeiríssima fatura), cai
// em nextInvoiceClosingDate_() (a acumulando a partir de hoje).
// Ex.: última fatura na planilha = 06/07/2026 → newInvoiceClosingDate_=06/08/2026.
// Spec: docs/specs/rules/invoice-closing-date.md
function newInvoiceClosingDate_(sheet) {
  const latest = latestInvoiceClosingInSheet_(sheet);
  if (!latest) return nextInvoiceClosingDate_();
  const parts = latest.split("/");
  let mm = parseInt(parts[1], 10) + 1;
  let yyyy = parseInt(parts[2], 10);
  if (mm > 12) {
    mm = 1;
    yyyy += 1;
  }
  const dd = ("0" + INVOICE_CLOSING_DAY).slice(-2);
  return dd + "/" + ("0" + mm).slice(-2) + "/" + yyyy;
}

// Acha a fatura anterior (a mais recente com data STRICTLY LESS THAN newClosing).
// Retorna { closing: "DD/MM/YYYY", rows: [{ rowIndex, values }] } ou null.
// rowIndex é 1-indexed (linha real na planilha).
function findCurrentInvoice_(sheet, newClosing) {
  const last = sheet.getLastRow();
  if (last < 2) return null;
  const data = sheet.getRange(2, 1, last - 1, 10).getValues();
  const newDate = parseBrDate_(newClosing);

  let bestClosing = null;
  let bestDate = null;
  for (let i = 0; i < data.length; i++) {
    const closing = formatBrDate_(data[i][0]);
    if (!closing) continue;
    const d = parseBrDate_(closing);
    if (d >= newDate) continue;
    if (bestDate === null || d > bestDate) {
      bestDate = d;
      bestClosing = closing;
    }
  }
  if (!bestClosing) return null;

  const rows = [];
  for (let i = 0; i < data.length; i++) {
    if (formatBrDate_(data[i][0]) === bestClosing) {
      rows.push({ rowIndex: i + 2, values: data[i] });
    }
  }
  return { closing: bestClosing, rows: rows };
}

// Rola uma linha de parcela para a fatura nova. Pula se col I não bate
// /^\d+\/\d+$/, ou se X >= Y, ou se col I vazia.
// Retorna array de 10 valores (nova linha) ou null.
function rolloverParcelaRow_(rowValues, newClosing) {
  const parcela = String(rowValues[8] || "").trim();
  const m = parcela.match(/^(\d+)\/(\d+)$/);
  if (!m) return null;
  const x = parseInt(m[1], 10);
  const y = parseInt(m[2], 10);
  if (!(x < y)) return null;
  return [
    parseBrDate_(newClosing),  // A — fatura nova (Date object, formato dd/MM/yyyy)
    rowValues[1],              // B — DataRef original (audit trail)
    rowValues[2],              // C — descrição
    rowValues[3],              // D — valor
    rowValues[4],              // E — origem
    rowValues[5],              // F — categoria
    rowValues[6],              // G — rateio
    rowValues[7],              // H — cartão
    (x + 1) + "/" + y,         // I — próxima parcela
    rowValues[9],              // J — acerto
  ];
}
