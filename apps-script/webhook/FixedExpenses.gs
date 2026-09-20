// Despesas fixas são lidas da aba `despesas-fixas` no momento da inserção.
// Spec: docs/specs/rules/fixed-expenses.md
// Schema da aba: docs/specs/data/despesas-fixas-sheet.md

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

    // Linha totalmente em branco (todas as 7 colunas vazias) é ignorada:
    // getLastRow() pode incluir linhas vazias no fim/meio quando sobra
    // conteúdo ou formatação numa célula qualquer. Uma linha PARCIALMENTE
    // preenchida continua sendo validada — é erro real, não branco intencional.
    if (r.every((c) => String(c).trim() === "")) continue;

    const [dia, descricao, valor, origem, categoria, rateio, acerto] = r;

    if (!Number.isInteger(dia) || dia < 1 || dia > 31)
      throw new Error(`despesas-fixas L${line}: dia inválido (${dia})`);
    if (!descricao || typeof descricao !== "string")
      throw new Error(`despesas-fixas L${line}: descrição vazia`);
    if (typeof valor !== "number" || isNaN(valor))
      throw new Error(`despesas-fixas L${line}: valor inválido (${valor})`);
    if (!origem) throw new Error(`despesas-fixas L${line}: origem vazia`);
    // Normaliza o enum antigo da col D. A aba foi migrada junto com Despesas em
    // 2026-09-20, mas uma linha nova digitada à mão pode trazer valor legado —
    // e ela vira lançamento de verdade na Nova fatura.
    const origemNorm = normalizeOrigem_(origem);
    if (ORIGENS.indexOf(origemNorm) < 0)
      throw new Error(`despesas-fixas L${line}: origem inválida (${origem})`);
    if (!categoria) throw new Error(`despesas-fixas L${line}: categoria vazia`);
    if (!["Julio", "Dani", "Metade", "Alzira"].includes(String(rateio)))
      throw new Error(`despesas-fixas L${line}: rateio inválido (${rateio})`);
    const acertoStr = String(acerto || "");
    if (acertoStr !== "" && acertoStr !== "Sim")
      throw new Error(`despesas-fixas L${line}: acerto inválido (${acertoStr})`);

    result.push({
      refDay: dia,
      description: descricao,
      value: valor,
      origem: origemNorm,
      categoria,
      rateio: String(rateio),
      acerto: acertoStr,
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
