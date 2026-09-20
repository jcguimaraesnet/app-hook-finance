// Despesas fixas são lidas da aba `despesas-fixas` no momento da inserção.
// Spec: docs/specs/rules/fixed-expenses.md
// Schema da aba: docs/specs/data/despesas-fixas-sheet.md

// Regras de validação da aba, em um lugar só: a leitura do webhook e os
// endpoints de edição compartilham daqui. Retorna {ok, value} ou {ok, error}.
// Spec: docs/specs/data/despesas-fixas-sheet.md
const FIXED_RATEIOS = ["Julio", "Dani", "Metade", "Alzira"];

function validateFixedExpense_(f) {
  const dia = Number(f.dia);
  if (!Number.isInteger(dia) || dia < 1 || dia > 31) {
    return { ok: false, error: `dia inválido (${f.dia})` };
  }
  const descricao = String(f.descricao === undefined ? "" : f.descricao).trim();
  if (!descricao) return { ok: false, error: "descrição vazia" };

  if (f.valor === undefined || f.valor === null || f.valor === "") {
    return { ok: false, error: "valor vazio" };
  }
  const valor = Number(f.valor);
  if (isNaN(valor)) return { ok: false, error: `valor inválido (${f.valor})` };

  const origemRaw = String(f.origem === undefined ? "" : f.origem).trim();
  if (!origemRaw) return { ok: false, error: "origem vazia" };
  // Normaliza o enum antigo da col D. A aba foi migrada junto com Despesas em
  // 2026-09-20, mas uma linha digitada à mão pode trazer valor legado — e ela
  // vira lançamento de verdade na Nova fatura.
  const origem = normalizeOrigem_(origemRaw);
  if (ORIGENS.indexOf(origem) < 0) {
    return { ok: false, error: `origem inválida (${origemRaw})` };
  }

  const categoria = String(f.categoria === undefined ? "" : f.categoria).trim();
  if (!categoria) return { ok: false, error: "categoria vazia" };

  const rateio = String(f.rateio === undefined ? "" : f.rateio).trim();
  if (FIXED_RATEIOS.indexOf(rateio) < 0) {
    return { ok: false, error: `rateio inválido (${f.rateio})` };
  }

  const acerto = String(f.acerto === undefined || f.acerto === null ? "" : f.acerto).trim();
  if (acerto !== "" && acerto !== "Sim") {
    return { ok: false, error: `acerto inválido (${acerto})` };
  }

  return {
    ok: true,
    value: { dia: dia, descricao: descricao, valor: valor, origem: origem,
             categoria: categoria, rateio: rateio, acerto: acerto },
  };
}

// Linha 100% em branco é ignorada: getLastRow() pode incluir linhas vazias no
// fim/meio quando sobra conteúdo ou formatação numa célula qualquer. Uma linha
// PARCIALMENTE preenchida NÃO é branco intencional — segue sendo validada.
function isBlankFixedRow_(r) {
  return r.every((c) => String(c).trim() === "");
}

function loadFixedExpenses_() {
  const ss = SpreadsheetApp.openById(SHEET_ID);
  const sheet = ss.getSheetByName(FIXED_SHEET_NAME);
  if (!sheet) throw new Error(`aba "${FIXED_SHEET_NAME}" não existe`);

  const last = sheet.getLastRow();
  if (last < 2) throw new Error(`aba "${FIXED_SHEET_NAME}" está vazia`);

  const rows = sheet.getRange(2, 1, last - 1, 7).getValues();
  const result = [];
  for (let i = 0; i < rows.length; i++) {
    const r = rows[i];
    const line = i + 2;
    if (isBlankFixedRow_(r)) continue;

    const v = validateFixedExpense_({
      dia: r[0], descricao: r[1], valor: r[2], origem: r[3],
      categoria: r[4], rateio: r[5], acerto: r[6],
    });
    // Lança, como sempre: uma linha ruim aqui trava a Nova fatura de propósito,
    // porque ela viraria lançamento errado na planilha. O endpoint de leitura da
    // tela faz o oposto — marca a linha e devolve, senão a tela que serve para
    // consertar seria a primeira a quebrar.
    if (!v.ok) throw new Error(`despesas-fixas L${line}: ${v.error}`);

    result.push({
      refDay: v.value.dia,
      description: v.value.descricao,
      value: v.value.valor,
      origem: v.value.origem,
      categoria: v.value.categoria,
      rateio: v.value.rateio,
      acerto: v.value.acerto,
    });
  }
  return result;
}

// Monta o bloco "início de fatura". Chamado pelo gatilho manual `newInvoice_`.
// Com parcelas: [blank, ...parcelaRows, blank (separador), ...fixedRows, blank, blank (vai virar azul), blank].
// Sem parcelas: [blank, ...fixedRows, blank, blank, blank].
// col A das linhas é Date object (não string) — applyInvoiceBlock_ aplica o
// formato dd/MM/yyyy depois do insert pra garantir display correto.
// Spec: docs/specs/rules/new-invoice.md, docs/specs/rules/fixed-expenses.md
function buildInvoiceBlock_(invoiceClosing, parcelaRows) {
  const fixed = loadFixedExpenses_();
  const closingDate = parseBrDate_(invoiceClosing);
  const [, mm, yyyy] = invoiceClosing.split("/");
  const fixedRows = fixed.map((e) => {
    const dd = ("0" + e.refDay).slice(-2);
    return [
      closingDate,
      dd + "/" + mm + "/" + yyyy,
      e.description,
      e.value,
      e.origem,
      e.categoria,
      e.rateio,
      "", // Final do cartão (n/a para Pix)
      "", // Parcela (despesas fixas nunca são parceladas)
      e.acerto || "",
    ];
  });
  const blank = ["", "", "", "", "", "", "", "", "", ""];
  const safeParcelas = parcelaRows || [];
  const separator = safeParcelas.length > 0 ? [blank] : [];
  const block = [blank]
    .concat(safeParcelas)
    .concat(separator)
    .concat(fixedRows)
    .concat([blank, blank, blank]);
  return { block: block, fixedCount: fixedRows.length };
}

// Aplica o bloco em sheet: insertRowsBefore(2, N) + formatos + setValues + linha azul.
// - col A (Data): força formato dd/MM/yyyy pra exibir Date objects corretamente
//   (sobrescreve qualquer @ herdado de updateEntry em linhas vizinhas).
// - col I (Parcela): força @ pra impedir Sheets auto-parsear "1/3" como data
//   (ver docs/specs/data/despesas-sheet.md).
// Spec: docs/specs/rules/fixed-expenses.md
function applyInvoiceBlock_(sheet, block) {
  sheet.insertRowsBefore(2, block.length);
  sheet.getRange(2, 1, block.length, 1).setNumberFormat("dd/MM/yyyy");
  sheet.getRange(2, 9, block.length, 1).setNumberFormat("@");
  sheet.getRange(2, 1, block.length, 10).setValues(block);
  // Linha azul = penúltima do bloco. Inserido a partir da linha 2,
  // então fica na linha (2 + block.length - 2) = block.length.
  sheet.getRange(block.length, 1, 1, 10).setBackground("#cfe2f3");
}

// Endpoint manual: insere bloco de fatura + rola parcelas pendentes.
// Spec: docs/specs/rules/new-invoice.md
function newInvoice_(token) {
  const auth = checkToken_(token);
  if (auth) return auth;

  const lock = LockService.getScriptLock();
  if (!lock.tryLock(10000)) {
    return { ok: false, error: "lock_timeout" };
  }
  try {
    const sheet = SpreadsheetApp.openById(SHEET_ID).getSheetByName(SHEET_NAME);
    if (!sheet) return { ok: false, error: "sheet_not_found" };

    // Data de fechamento ancorada na última fatura da planilha + 1 mês. Lida
    // DENTRO do lock pra ver o estado consistente (nenhum webhook/insert em voo).
    // Spec: docs/specs/rules/invoice-closing-date.md
    const newClosing = newInvoiceClosingDate_(sheet);

    // Dedup: já existe alguma linha com essa data de fechamento?
    const last = sheet.getLastRow();
    if (last > 1) {
      const colA = sheet.getRange(2, 1, last - 1, 1).getValues();
      for (let i = 0; i < colA.length; i++) {
        if (formatBrDate_(colA[i][0]) === newClosing) {
          return { ok: false, error: "invoice_already_exists", invoiceClosing: newClosing };
        }
      }
    }

    // Rollover de parcelas pendentes da fatura anterior.
    const current = findCurrentInvoice_(sheet, newClosing);
    const parcelaRows = [];
    if (current) {
      for (let i = 0; i < current.rows.length; i++) {
        const rolled = rolloverParcelaRow_(current.rows[i].values, newClosing);
        if (rolled) parcelaRows.push(rolled);
      }
    }

    let block, fixedCount;
    try {
      const built = buildInvoiceBlock_(newClosing, parcelaRows);
      block = built.block;
      fixedCount = built.fixedCount;
    } catch (e) {
      return { ok: false, error: "fixed_expenses_failed", detail: String(e && e.message ? e.message : e) };
    }

    applyInvoiceBlock_(sheet, block);

    return {
      ok: true,
      invoiceClosing: newClosing,
      fixedCount: fixedCount,
      parcelaCount: parcelaRows.length,
    };
  } finally {
    try { lock.releaseLock(); } catch (_) {}
  }
}

// Endpoint read-only (GET): devolve a data de fechamento que "Nova fatura"
// criaria agora (última fatura da planilha + 1 mês), sem inserir nada. Usado
// pelo dialog de confirmação do app pra exibir a data antes do POST — já que
// o cálculo depende do estado da planilha e o cliente não consegue prevê-lo.
// Spec: docs/specs/rules/new-invoice.md
function previewNewInvoice_(token) {
  const auth = checkToken_(token);
  if (auth) return auth;
  const sheet = SpreadsheetApp.openById(SHEET_ID).getSheetByName(SHEET_NAME);
  if (!sheet) return { ok: false, error: "sheet_not_found" };
  return { ok: true, invoiceClosing: newInvoiceClosingDate_(sheet) };
}

// One-shot — rodar manualmente no editor do Apps Script para popular a aba
// `despesas-fixas` com a lista atual. Idempotente: aborta se a aba já tem dados.
function seedFixedExpenses() {
  const ss = SpreadsheetApp.openById(SHEET_ID);
  const sheet = ss.getSheetByName(FIXED_SHEET_NAME);
  if (!sheet) throw new Error(`crie a aba "${FIXED_SHEET_NAME}" primeiro`);
  if (sheet.getLastRow() > 1)
    throw new Error("aba já tem dados — abortando para não duplicar");

  const headers = ["Dia", "Descrição", "Valor", "Origem", "Categoria", "Rateio", "Acerto"];
  const data = [
    [6,  "Diarista",                                                       1500,    "Pix (contas)", "Contas", "Dani",  ""   ],
    [6,  "Plano de Saúde (Dani)",                                          761.81,  "Pix (contas)", "Contas", "Dani",  ""   ],
    [6,  "Plano de Saúde (Julio)",                                         761.81,  "Pix (contas)", "Contas", "Julio", "Sim"],
    [7,  "Mensalidade creche 1/2",                                         1741.40, "Pix (contas)", "Contas", "Dani",  "Sim"],
    [7,  "Mensalidade creche 2/2",                                         1741.40, "Pix (contas)", "Contas", "Julio", "Sim"],
    [5,  "Ajuda de custo (Creche)",                                        -620,    "Pix (contas)", "Contas", "Dani",  ""   ],
    [6,  "Claro Internet - https://minhaclaroresidencial.claro.com.br",    0.01,    "Pix (contas)", "Contas", "Dani",  ""   ],
    [5,  "Gás",                                                            120.42,  "Pix (contas)", "Contas", "Dani",  "Sim"],
    [10, "Condomínio 1/2",                                                 1550,    "Pix (contas)", "Contas", "Julio", "Sim"],
    [10, "Condomínio 1/2",                                                 0,       "Pix (contas)", "Contas", "Dani",  ""   ],
    [7,  "Energia (débito automático)",                                    500,     "Pix (contas)", "Contas", "Dani",  ""   ],
    [15, "Guia de Previdência Social",                                     1300,    "Pix (contas)", "Contas", "Julio", ""   ],
    [15, "Guia de Previdência Social (coloquei pra Dani pra equilibrar)",  1300,    "Pix (contas)", "Contas", "Dani",  ""   ],
    [5,  "Dízimo",                                                         500,     "Pix (contas)", "Contas", "Julio", ""   ],
    [5,  "Dízimo",                                                         500,     "Pix (contas)", "Contas", "Dani",  ""   ],
  ];

  sheet.getRange(1, 1, 1, headers.length).setValues([headers]).setFontWeight("bold");
  sheet.getRange(2, 1, data.length, headers.length).setValues(data);
}

// ---------------------------------------------------------------------------
// CRUD da aba para a tela de Despesas fixas (pós-2026-09-20).
// Spec: docs/specs/api/endpoints.md, docs/specs/pages/despesas-fixas.md
// ---------------------------------------------------------------------------

// Leitura tolerante: devolve TODAS as linhas não-vazias, inclusive as inválidas,
// com `invalid` preenchido. Diferente de loadFixedExpenses_, que lança — aqui
// derrubar a resposta esconderia justamente a linha que precisa de conserto.
// `row` é a linha real da aba, necessária para editar/excluir.
function getFixedExpenses(token) {
  const auth = checkToken_(token);
  if (auth) return auth;
  const sheet = SpreadsheetApp.openById(SHEET_ID).getSheetByName(FIXED_SHEET_NAME);
  if (!sheet) return { ok: false, error: "fixed_sheet_not_found" };

  const last = sheet.getLastRow();
  if (last < 2) return { ok: true, rows: [] };

  const values = sheet.getRange(2, 1, last - 1, 7).getValues();
  const rows = [];
  for (let i = 0; i < values.length; i++) {
    const r = values[i];
    if (isBlankFixedRow_(r)) continue;
    const raw = {
      dia: r[0], descricao: String(r[1] || ""), valor: r[2],
      origem: String(r[3] || ""), categoria: String(r[4] || ""),
      rateio: String(r[5] || ""), acerto: String(r[6] || ""),
    };
    const v = validateFixedExpense_(raw);
    rows.push({
      row: i + 2,
      dia: Number(raw.dia) || 0,
      descricao: raw.descricao,
      valor: Number(raw.valor) || 0,
      origem: v.ok ? v.value.origem : raw.origem,
      categoria: raw.categoria,
      rateio: raw.rateio,
      acerto: raw.acerto,
      invalid: v.ok ? "" : v.error,
    });
  }
  return { ok: true, rows: rows };
}

// Insere no fim da aba: a ordem das linhas define a ordem do bloco inserido na
// Nova fatura, então inserir no topo mudaria o layout da fatura sem pedir.
function addFixedExpense(token, fields) {
  const auth = checkToken_(token);
  if (auth) return auth;
  const v = validateFixedExpense_(fields || {});
  if (!v.ok) return { ok: false, error: "invalid_fields", detail: v.error };

  const sheet = SpreadsheetApp.openById(SHEET_ID).getSheetByName(FIXED_SHEET_NAME);
  if (!sheet) return { ok: false, error: "fixed_sheet_not_found" };

  const row = Math.max(sheet.getLastRow(), 1) + 1;
  writeFixedExpenseRow_(sheet, row, v.value);
  return { ok: true, row: row };
}

function updateFixedExpense(token, row, fields) {
  const auth = checkToken_(token);
  if (auth) return auth;
  if (!row || row < 2) return { ok: false, error: "invalid_row" };
  const v = validateFixedExpense_(fields || {});
  if (!v.ok) return { ok: false, error: "invalid_fields", detail: v.error };

  const sheet = SpreadsheetApp.openById(SHEET_ID).getSheetByName(FIXED_SHEET_NAME);
  if (!sheet) return { ok: false, error: "fixed_sheet_not_found" };
  if (row > sheet.getLastRow()) return { ok: false, error: "row_out_of_range" };

  writeFixedExpenseRow_(sheet, row, v.value);
  return { ok: true, row: row };
}

function deleteFixedExpense(token, row) {
  const auth = checkToken_(token);
  if (auth) return auth;
  if (!row || row < 2) return { ok: false, error: "invalid_row" };
  const sheet = SpreadsheetApp.openById(SHEET_ID).getSheetByName(FIXED_SHEET_NAME);
  if (!sheet) return { ok: false, error: "fixed_sheet_not_found" };
  if (row > sheet.getLastRow()) return { ok: false, error: "row_out_of_range" };

  sheet.deleteRow(row);
  return { ok: true };
}

function writeFixedExpenseRow_(sheet, row, v) {
  sheet.getRange(row, 1, 1, 7).setValues([[
    v.dia, v.descricao, v.valor, v.origem, v.categoria, v.rateio, v.acerto,
  ]]);
}
