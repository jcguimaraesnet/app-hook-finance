function doGet(e) {
  const action = (e && e.parameter && e.parameter.action) || "";
  switch (action) {
    case "data":
      return jsonResponse_(readAllForApi_(e.parameter.token));
    case "monthData":
      return jsonResponse_(getMonthData(e.parameter.token, e.parameter.month || null));
    case "historicalSummary":
      return jsonResponse_(getHistoricalSummary(e.parameter.token));
    case "lastEntries":
      return jsonResponse_(getLastEntries(e.parameter.token, parseInt(e.parameter.n, 10) || 10));
    case "newInvoicePreview":
      return jsonResponse_(previewNewInvoice_(e.parameter.token));
    default:
      return jsonResponse_({ ok: false, error: "unknown_action" });
  }
}

function doPost(e) {
  const body = parsePostBody_((e && e.postData && e.postData.contents) || "{}");
  if (!body) {
    return jsonResponse_({ ok: false, error: "invalid_json" });
  }

  // Caminho legado do webhook (Tasker/IFTTT envia title+text).
  if (body.title && body.text) {
    return jsonResponse_(handleWebhookBody_(body));
  }

  // Caminho REST.
  switch (body.action) {
    case "addEntry":
      return jsonResponse_(addEntry(body.token, body.fields));
    case "updateEntry":
      return jsonResponse_(updateEntry(body.token, body.row, body.fields));
    case "deleteEntry":
      return jsonResponse_(deleteEntry(body.token, body.row));
    case "newInvoice":
      return jsonResponse_(newInvoice_(body.token));
    case "ensureHeader":
      return jsonResponse_(ensureHeader(body.token));
    default:
      return jsonResponse_({ ok: false, error: "unknown_action" });
  }
}

// JSON.parse rejeita control chars crus dentro de string. O job do celular monta
// o body por concatenação, e a notificação da Revolut tem "\n" entre as frases;
// se ele chegar sem escape, o parse estrito falha. Fallback: escapa CR/LF/TAB
// e tenta de novo. Retorna null se nem assim for JSON válido.
// Spec: docs/specs/api/webhook.md
function parsePostBody_(contents) {
  try {
    return JSON.parse(contents);
  } catch (_) {
    // segue pro fallback
  }
  const escaped = contents
    .replace(/\r/g, "\\r")
    .replace(/\n/g, "\\n")
    .replace(/\t/g, "\\t");
  try {
    return JSON.parse(escaped);
  } catch (_) {
    return null;
  }
}

function getMonthData(token, month) {
  const auth = checkToken_(token);
  if (auth) return auth;
  const sheet = SpreadsheetApp.openById(SHEET_ID).getSheetByName(SHEET_NAME);
  if (!sheet) return { ok: false, error: "sheet_not_found" };
  const last = sheet.getLastRow();
  if (last < 2) return { ok: true, month: null, rows: [] };

  const tz = Session.getScriptTimeZone();
  const fmtCache = {};
  const fmt = function (v) {
    if (v instanceof Date) {
      const t = v.getTime();
      if (fmtCache[t]) return fmtCache[t];
      const s = Utilities.formatDate(v, tz, "dd/MM/yyyy");
      fmtCache[t] = s;
      return s;
    }
    return String(v || "").trim();
  };

  const dataCol = sheet
    .getRange(2, 1, last - 1, 1)
    .getValues()
    .map((r) => fmt(r[0]));

  let targetMonth = month || "";
  if (!targetMonth) {
    let maxKey = -Infinity;
    for (let i = 0; i < dataCol.length; i++) {
      const d = dataCol[i];
      if (!d) continue;
      const key = parseBrDate_(d).getTime();
      if (!isNaN(key) && key > maxKey) {
        maxKey = key;
        targetMonth = d;
      }
    }
  }
  if (!targetMonth) return { ok: true, month: null, rows: [] };

  const matchIndexes = [];
  for (let i = 0; i < dataCol.length; i++) {
    if (dataCol[i] === targetMonth) matchIndexes.push(i + 2);
  }
  if (matchIndexes.length === 0) {
    return { ok: true, month: targetMonth, rows: [] };
  }

  const minRow = matchIndexes[0];
  const maxRow = matchIndexes[matchIndexes.length - 1];
  const slab = sheet.getRange(minRow, 1, maxRow - minRow + 1, 10).getValues();
  // Loop em vez de filter+map: `row` é a linha real da planilha (minRow + i),
  // que o cliente usa em updateEntry/deleteEntry. Um filter antes do map perderia
  // o índice, e a posição no array não serve — o slab tem linhas de outros meses
  // no meio (bloco de início de fatura).
  const rows = [];
  for (let i = 0; i < slab.length; i++) {
    const r = slab[i];
    if (fmt(r[0]) !== targetMonth) continue;
    rows.push({
      row: minRow + i,
      data: fmt(r[0]),
      dataRef: typeof r[1] === "string" ? r[1] : fmt(r[1]),
      descricao: String(r[2] || ""),
      valor: Number(r[3]) || 0,
      origem: String(r[4] || ""),
      categoria: String(r[5] || ""),
      rateio: String(r[6] || ""),
      banco: String(r[7] || ""),
      parcela: String(r[8] || "").trim(),
      acerto: String(r[9] || ""),
    });
  }

  return { ok: true, month: targetMonth, rows: rows };
}

function getHistoricalSummary(token) {
  const auth = checkToken_(token);
  if (auth) return auth;
  const sheet = SpreadsheetApp.openById(SHEET_ID).getSheetByName(SHEET_NAME);
  if (!sheet) return { ok: false, error: "sheet_not_found" };
  const last = sheet.getLastRow();
  if (last < 2) {
    return {
      ok: true,
      months: [],
      history: { months: [], totals: [], julioPessoal: [], daniPessoal: [] },
    };
  }

  const tz = Session.getScriptTimeZone();
  const fmtCache = {};
  const fmt = function (v) {
    if (v instanceof Date) {
      const t = v.getTime();
      if (fmtCache[t]) return fmtCache[t];
      const s = Utilities.formatDate(v, tz, "dd/MM/yyyy");
      fmtCache[t] = s;
      return s;
    }
    return String(v || "").trim();
  };

  // 1) Lê só coluna A para descobrir os 12 meses mais recentes e o range coberto.
  const dataCol = sheet.getRange(2, 1, last - 1, 1).getValues();
  const monthByRow = new Array(dataCol.length);
  const allMonths = {};
  for (let i = 0; i < dataCol.length; i++) {
    const m = fmt(dataCol[i][0]);
    monthByRow[i] = m;
    if (m) allMonths[m] = true;
  }

  const monthsDesc = Object.keys(allMonths).sort(
    (a, b) => parseBrDate_(b) - parseBrDate_(a),
  );
  const last12Desc = monthsDesc.slice(0, 12);
  if (last12Desc.length === 0) {
    return {
      ok: true,
      months: [],
      history: { months: [], totals: [], julioPessoal: [], daniPessoal: [] },
    };
  }
  const last12Set = {};
  for (const m of last12Desc) last12Set[m] = true;

  // 2) Encontra range de linhas que cobre os últimos 12 meses.
  let minIdx = -1;
  let maxIdx = -1;
  for (let i = 0; i < monthByRow.length; i++) {
    if (last12Set[monthByRow[i]]) {
      if (minIdx === -1) minIdx = i;
      maxIdx = i;
    }
  }
  if (minIdx === -1) {
    return {
      ok: true,
      months: [],
      history: { months: [], totals: [], julioPessoal: [], daniPessoal: [] },
    };
  }

  // 3) Lê A..G só do slab necessário.
  const slabStart = minIdx + 2;
  const slabRows = maxIdx - minIdx + 1;
  const values = sheet.getRange(slabStart, 1, slabRows, 7).getValues();

  const byMonth = {};
  for (const m of last12Desc) {
    byMonth[m] = { total: 0, julioPessoal: 0, daniPessoal: 0 };
  }
  for (const r of values) {
    const data = fmt(r[0]);
    if (!data || !last12Set[data]) continue;
    const valor = Number(r[3]) || 0;
    const origem = String(r[4] || "");
    const rateio = String(r[6] || "");
    if (origem !== "Pessoal") byMonth[data].total += valor;
    // "Pessoal" segue Regra 2: Cartão + rateio em {Julio, Dani} (full value).
    if (origem === "Cartão") {
      if (rateio === "Julio") byMonth[data].julioPessoal += valor;
      else if (rateio === "Dani") byMonth[data].daniPessoal += valor;
    }
  }

  const last12Asc = last12Desc.slice().reverse();

  return {
    ok: true,
    months: last12Desc,
    history: {
      months: last12Asc,
      totals: last12Asc.map((m) => byMonth[m].total),
      julioPessoal: last12Asc.map((m) => byMonth[m].julioPessoal),
      daniPessoal: last12Asc.map((m) => byMonth[m].daniPessoal),
    },
  };
}

function getLastEntries(token, n) {
  const auth = checkToken_(token);
  if (auth) return auth;
  const sheet = SpreadsheetApp.openById(SHEET_ID).getSheetByName(SHEET_NAME);
  if (!sheet) return { ok: false, error: "sheet_not_found" };
  const last = sheet.getLastRow();
  if (last < 2) return { ok: true, entries: [] };

  const requested = n || 10;
  // Lê um slab maior que `requested` pra ter folga ao pular linhas em branco
  // (bloco "início de fatura" cria ~5 brancas no topo a cada Nova fatura).
  // O cap garante que mesmo com várias faturas seguidas conseguimos preencher N.
  const slabSize = Math.min(requested + 30, last - 1);
  const values = sheet.getRange(2, 1, slabSize, 10).getValues();

  const tz = Session.getScriptTimeZone();
  const fmtDate = function (v) {
    if (v instanceof Date) return Utilities.formatDate(v, tz, "dd/MM/yyyy");
    return String(v || "").trim();
  };
  const fmtDateTime = function (v) {
    if (v instanceof Date) return Utilities.formatDate(v, tz, "dd/MM/yyyy HH:mm");
    return String(v || "").trim();
  };

  const entries = [];
  for (let i = 0; i < values.length && entries.length < requested; i++) {
    const r = values[i];
    const data = fmtDate(r[0]);
    const descricao = String(r[2] || "").trim();
    // Pula linhas em branco do bloco de Nova fatura (data E descrição vazias).
    if (!data && !descricao) continue;
    entries.push({
      row: i + 2,
      data: data,
      dataRef: fmtDateTime(r[1]),
      descricao: String(r[2] || ""),
      valor: Number(r[3]) || 0,
      origem: String(r[4] || ""),
      categoria: String(r[5] || ""),
      rateio: String(r[6] || ""),
      banco: String(r[7] || ""),
      parcela: String(r[8] || "").trim(),
      acerto: String(r[9] || ""),
    });
  }

  return { ok: true, entries: entries };
}

// Enums aceitos por addEntry. Espelha o spec em docs/specs/data/despesas-sheet.md.
const ADD_ENTRY_ORIGEMS = ["Cartão", "Pix (contas)", "Pessoal", "Empregados", "Contas"];
const ADD_ENTRY_RATEIOS = ["", "Julio", "Dani", "Metade", "Alzira"];
const ADD_ENTRY_PARCELA_RE = /^\d+\/\d+$/;
const BR_DATE_RE = /^\d{2}\/\d{2}\/\d{4}$/;

// Headers da linha 1. Espelha docs/specs/data/despesas-sheet.md.
const SHEET_HEADERS = [
  "Data",
  "Data Referência",
  "Descrição",
  "Valor",
  "Origem",
  "Categoria",
  "Rateio",
  "Banco",
  "Parcela",
  "Acerto",
];

// Função, não const global: o Apps Script avalia dashboard/Dashboard.gs antes
// de shared/Constants.gs, e um `const` no topo referenciando BANCOS quebraria
// a carga do script inteiro (TDZ). Dentro de função, resolve em runtime.
function addEntryBancos_() {
  return [""].concat(BANCOS);
}

function addEntry(token, fields) {
  const auth = checkToken_(token);
  if (auth) return auth;
  fields = fields || {};

  const descricao = String(fields.descricao || "").trim();
  if (!descricao) return { ok: false, error: "missing_descricao" };

  const valorRaw = fields.valor;
  if (valorRaw === undefined || valorRaw === null || valorRaw === "") {
    return { ok: false, error: "missing_valor" };
  }
  const valor = Number(valorRaw);
  if (isNaN(valor)) return { ok: false, error: "invalid_valor" };

  const origem = String(fields.origem || "").trim();
  if (!origem) return { ok: false, error: "missing_origem" };
  if (ADD_ENTRY_ORIGEMS.indexOf(origem) < 0) return { ok: false, error: "invalid_origem" };

  const rateio = String(fields.rateio || "").trim();
  if (ADD_ENTRY_RATEIOS.indexOf(rateio) < 0) return { ok: false, error: "invalid_rateio" };

  const banco = String(fields.banco || "").trim();
  if (addEntryBancos_().indexOf(banco) < 0) return { ok: false, error: "invalid_banco" };

  const parcela = String(fields.parcela || "").trim();
  if (parcela && !ADD_ENTRY_PARCELA_RE.test(parcela)) {
    return { ok: false, error: "invalid_parcela" };
  }

  const acerto = String(fields.acerto || "").trim();
  if (acerto && acerto !== "Sim") return { ok: false, error: "invalid_acerto" };

  const tz = Session.getScriptTimeZone();
  const now = new Date();
  const data = String(fields.data || Utilities.formatDate(now, tz, "dd/MM/yyyy")).trim();
  if (!BR_DATE_RE.test(data)) return { ok: false, error: "invalid_data" };
  const dataRef = String(
    fields.dataRef || Utilities.formatDate(now, tz, "dd/MM/yyyy HH:mm"),
  ).trim();
  const categoria = String(fields.categoria || "").trim();

  const lock = LockService.getScriptLock();
  try {
    if (!lock.tryLock(10000)) {
      return { ok: false, error: "lock_timeout" };
    }
    const sheet = SpreadsheetApp.openById(SHEET_ID).getSheetByName(SHEET_NAME);
    if (!sheet) return { ok: false, error: "sheet_not_found" };

    insertRowsAtTop_(sheet, [[
      parseBrDate_(data), // col A é Date, como no webhook — nunca string.
      dataRef,
      descricao,
      valor,
      origem,
      categoria,
      rateio,
      banco,
      "", // Parcela — preenchida abaixo com setNumberFormat("@") protegido.
      acerto,
    ]]);
    sheet.getRange(2, 1).setNumberFormat("dd/MM/yyyy");
    if (parcela) {
      const parcelaCell = sheet.getRange(2, 9);
      parcelaCell.setNumberFormat("@");
      parcelaCell.setValue(parcela);
    }

    return { ok: true, row: 2 };
  } catch (err) {
    return { ok: false, error: String((err && err.message) || err) };
  } finally {
    try {
      lock.releaseLock();
    } catch (_) {
      // ignora
    }
  }
}

function updateEntry(token, row, fields) {
  const auth = checkToken_(token);
  if (auth) return auth;
  if (!row || row < 2) return { ok: false, error: "invalid_row" };
  const sheet = SpreadsheetApp.openById(SHEET_ID).getSheetByName(SHEET_NAME);
  if (!sheet) return { ok: false, error: "sheet_not_found" };
  if (row > sheet.getLastRow()) return { ok: false, error: "row_out_of_range" };
  fields = fields || {};

  const data = String(fields.data || "").trim();
  if (!data) return { ok: false, error: "missing_data" };
  if (!BR_DATE_RE.test(data)) return { ok: false, error: "invalid_data" };

  const dataRef = String(fields.dataRef || "").trim();
  if (!dataRef) return { ok: false, error: "missing_dataRef" };

  const origem = String(fields.origem || "").trim();
  if (!origem) return { ok: false, error: "missing_origem" };
  if (ADD_ENTRY_ORIGEMS.indexOf(origem) < 0) return { ok: false, error: "invalid_origem" };

  // `banco` é opcional: clientes antigos (APK pré-2026-09-12) não mandam o campo
  // e não podem apagar a col H sem querer. Só validamos/gravamos se veio no body.
  const hasBanco = fields.banco !== undefined && fields.banco !== null;
  const banco = hasBanco ? String(fields.banco).trim() : "";
  if (hasBanco && addEntryBancos_().indexOf(banco) < 0) {
    return { ok: false, error: "invalid_banco" };
  }

  // Colunas: A=data(1), B=dataRef(2), C=descricao(3), D=valor(4), E=origem(5),
  // F=categoria(6), G=rateio(7), H=banco(8, opcional), I=parcela(9)
  // Col A é Date (mesma convenção do webhook e do Nova fatura). Até 2026-09-12
  // este endpoint forçava "@" e gravava string — era a origem das datas de
  // fatura em texto na planilha. Grava Date e força o formato de exibição.
  const dataCell = sheet.getRange(row, 1);
  dataCell.setNumberFormat("dd/MM/yyyy");
  dataCell.setValue(parseBrDate_(data));

  // Força TEXT na col B pra evitar auto-parse pra datetime do Sheets.
  const dataRefCell = sheet.getRange(row, 2);
  dataRefCell.setNumberFormat("@");
  dataRefCell.setValue(dataRef);

  sheet.getRange(row, 3).setValue(String(fields.descricao || ""));
  sheet.getRange(row, 4).setValue(Number(fields.valor) || 0);
  sheet.getRange(row, 5).setValue(origem);
  sheet.getRange(row, 6).setValue(String(fields.categoria || ""));
  sheet.getRange(row, 7).setValue(String(fields.rateio || ""));
  if (hasBanco) sheet.getRange(row, 8).setValue(banco);

  // Força TEXT na col I (Parcela) pra evitar auto-parse de "1/3" como data.
  const parcelaCell = sheet.getRange(row, 9);
  parcelaCell.setNumberFormat("@");
  parcelaCell.setValue(String(fields.parcela || ""));

  return { ok: true, row: row };
}

// Garante que a linha 1 é o cabeçalho. Se a linha 1 já começa com "Data",
// só reescreve os headers (idempotente). Se a linha 1 for um lançamento (caso
// real em 2026-09-12: header apagado e uma compra ficou invisível pro app,
// que lê a partir da linha 2), insere uma linha acima e grava os headers nela.
// Spec: docs/specs/data/despesas-sheet.md
function ensureHeader(token) {
  const auth = checkToken_(token);
  if (auth) return auth;
  const lock = LockService.getScriptLock();
  try {
    if (!lock.tryLock(10000)) {
      return { ok: false, error: "lock_timeout" };
    }
    const sheet = SpreadsheetApp.openById(SHEET_ID).getSheetByName(SHEET_NAME);
    if (!sheet) return { ok: false, error: "sheet_not_found" };
    const first = String(sheet.getRange(1, 1).getValue() || "").trim();
    const hadHeader = first === SHEET_HEADERS[0];
    if (!hadHeader) sheet.insertRowsBefore(1, 1);
    const range = sheet.getRange(1, 1, 1, SHEET_HEADERS.length);
    range.setNumberFormat("@");
    range.setValues([SHEET_HEADERS]);
    range.setFontWeight("bold");
    return { ok: true, inserted: !hadHeader };
  } catch (err) {
    return { ok: false, error: String((err && err.message) || err) };
  } finally {
    try {
      lock.releaseLock();
    } catch (_) {
      // ignora
    }
  }
}

function deleteEntry(token, row) {
  const auth = checkToken_(token);
  if (auth) return auth;
  if (!row || row < 2) return { ok: false, error: "invalid_row" };
  const sheet = SpreadsheetApp.openById(SHEET_ID).getSheetByName(SHEET_NAME);
  if (!sheet) return { ok: false, error: "sheet_not_found" };
  if (row > sheet.getLastRow()) return { ok: false, error: "row_out_of_range" };
  sheet.deleteRow(row);
  return { ok: true };
}

function checkToken_(token) {
  const expected = PropertiesService.getScriptProperties().getProperty(
    "WEBHOOK_TOKEN",
  );
  if (!expected || token !== expected) {
    return { ok: false, error: "unauthorized" };
  }
  return null;
}

function mapRow_(r) {
  return {
    data: formatBrDate_(r[0]),
    dataRef: typeof r[1] === "string" ? r[1] : formatBrDate_(r[1]),
    descricao: String(r[2] || ""),
    valor: Number(r[3]) || 0,
    origem: String(r[4] || ""),
    categoria: String(r[5] || ""),
    rateio: String(r[6] || ""),
    banco: String(r[7] || ""),
    parcela: String(r[8] || "").trim(),
    acerto: String(r[9] || ""),
  };
}

function readData_(token) {
  const auth = checkToken_(token);
  if (auth) return auth;
  const sheet = SpreadsheetApp.openById(SHEET_ID).getSheetByName(SHEET_NAME);
  if (!sheet) return { ok: false, error: "sheet_not_found" };
  const last = sheet.getLastRow();
  if (last < 2) return { ok: true, rows: [] };
  const values = sheet.getRange(2, 1, last - 1, 10).getValues();
  return { ok: true, rows: values.map(mapRow_) };
}

function readAllForApi_(token) {
  return readData_(token);
}
