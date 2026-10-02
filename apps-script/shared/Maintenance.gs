// Rotinas one-off. Rodar manualmente no editor do Apps Script (botão Run).
// Não são expostas via doGet/doPost.

// Migra a col E (Origem) do enum de 5 valores para Crédito | Débito, nas duas
// abas: Despesas (col E) e despesas-fixas (col D). Sem migrar a segunda, a
// Nova fatura volta a inserir "Pix (contas)" no mês seguinte.
//
// Mapa: Cartão → Crédito; Pix (contas) | Contas | Empregados | Pessoal → Débito.
// Célula vazia fica vazia (linhas em branco do bloco de início de fatura).
// Valor desconhecido é reportado e **não** é tocado — melhor deixar visível que
// adivinhar num dado de dinheiro.
//
// Idempotente: valores já migrados são ignorados; rodar de novo não faz nada.
// Spec: docs/specs/data/despesas-sheet.md (Migração de Origem)
function migrateOrigemToCreditoDebito() {
  const ss = SpreadsheetApp.openById(SHEET_ID);

  const despesas = migrateOrigemColumn_(ss.getSheetByName(SHEET_NAME), 5, SHEET_NAME);
  const fixas = migrateOrigemColumn_(
    ss.getSheetByName(FIXED_SHEET_NAME),
    4,
    FIXED_SHEET_NAME,
  );

  const resumo =
    `Despesas: ${despesas.changed} migradas, ${despesas.kept} já ok, ` +
    `${despesas.blank} vazias, ${despesas.unknown.length} desconhecidas\n` +
    `despesas-fixas: ${fixas.changed} migradas, ${fixas.kept} já ok, ` +
    `${fixas.blank} vazias, ${fixas.unknown.length} desconhecidas`;
  Logger.log(resumo);

  const unknown = despesas.unknown.concat(fixas.unknown);
  if (unknown.length) {
    Logger.log("Valores não reconhecidos (deixados como estão):");
    for (const u of unknown) Logger.log("  " + u);
  }
  return resumo;
}

function migrateOrigemColumn_(sheet, col, label) {
  if (!sheet) throw new Error(`aba "${label}" não existe`);
  const last = sheet.getLastRow();
  const out = { changed: 0, kept: 0, blank: 0, unknown: [] };
  if (last < 2) return out;

  const range = sheet.getRange(2, col, last - 1, 1);
  const values = range.getValues();
  const novos = values.map((r, i) => {
    const raw = String(r[0] === null || r[0] === undefined ? "" : r[0]).trim();
    if (!raw) {
      out.blank++;
      return [r[0]];
    }
    if (ORIGENS.indexOf(raw) >= 0) {
      out.kept++;
      return [raw];
    }
    const norm = normalizeOrigem_(raw);
    if (ORIGENS.indexOf(norm) < 0) {
      out.unknown.push(`${label} L${i + 2}: "${raw}"`);
      return [r[0]];
    }
    out.changed++;
    return [norm];
  });

  if (out.changed > 0) range.setValues(novos);
  return out;
}

// Wrapper com token para rodar a migração pela API, no mesmo padrão de
// `ensureHeader`. Idempotente — a rotina ignora o que já está migrado.
// Pode ser removido junto com a ponte de normalização quando a planilha não
// tiver mais valor legado.
function migrateOrigem(token) {
  const auth = checkToken_(token);
  if (auth) return auth;
  try {
    const despesas = migrateOrigemColumn_(
      SpreadsheetApp.openById(SHEET_ID).getSheetByName(SHEET_NAME),
      5,
      SHEET_NAME,
    );
    const fixas = migrateOrigemColumn_(
      SpreadsheetApp.openById(SHEET_ID).getSheetByName(FIXED_SHEET_NAME),
      4,
      FIXED_SHEET_NAME,
    );
    return { ok: true, despesas: despesas, fixas: fixas };
  } catch (err) {
    return { ok: false, error: String((err && err.message) || err) };
  }
}

// Troca "Metade" por "Compartilhado" na col G de Despesas e na col F de
// despesas-fixas. Escreve a célula direto, sem passar pela validação dos
// endpoints. Idempotente.
// Spec: docs/specs/data/despesas-sheet.md (col G)
function migrateRateio(token) {
  const auth = checkToken_(token);
  if (auth) return auth;
  try {
    const ss = SpreadsheetApp.openById(SHEET_ID);
    return {
      ok: true,
      despesas: migrateRateioColumn_(ss.getSheetByName(SHEET_NAME), 7, SHEET_NAME),
      fixas: migrateRateioColumn_(ss.getSheetByName(FIXED_SHEET_NAME), 6, FIXED_SHEET_NAME),
    };
  } catch (err) {
    return { ok: false, error: String((err && err.message) || err) };
  }
}

function migrateRateioColumn_(sheet, col, label) {
  if (!sheet) throw new Error(`aba "${label}" não existe`);
  const last = sheet.getLastRow();
  const out = { changed: 0, kept: 0, blank: 0 };
  if (last < 2) return out;

  const range = sheet.getRange(2, col, last - 1, 1);
  const values = range.getValues();
  const novos = values.map((r) => {
    const raw = String(r[0] === null || r[0] === undefined ? "" : r[0]).trim();
    if (!raw) {
      out.blank++;
      return [r[0]];
    }
    if (raw !== RATEIO_COMPARTILHADO_LEGADO) {
      out.kept++;
      return [raw];
    }
    out.changed++;
    return [RATEIO_COMPARTILHADO];
  });

  if (out.changed > 0) range.setValues(novos);
  return out;
}

// ---------------------------------------------------------------------------
// 2026-10-02: a coluna "Acerto" passou a dizer QUEM reembolsa a despesa, então
// o cabeçalho virou "Reembolso" nas duas abas. Só o texto da linha 1 muda —
// nenhum valor é tocado. Idempotente: rodar de novo não faz nada.
// Spec: docs/specs/data/despesas-sheet.md
// ---------------------------------------------------------------------------
function renameAcertoHeader(token) {
  const auth = checkToken_(token);
  if (auth) return auth;
  const ss = SpreadsheetApp.openById(SHEET_ID);
  const alvos = [
    { nome: SHEET_NAME, col: 10 },
    { nome: FIXED_SHEET_NAME, col: 7 },
  ];
  const out = [];
  for (const alvo of alvos) {
    const sheet = ss.getSheetByName(alvo.nome);
    if (!sheet) {
      out.push({ sheet: alvo.nome, skipped: "sheet_not_found" });
      continue;
    }
    const cell = sheet.getRange(1, alvo.col);
    const antes = String(cell.getValue() || "").trim();
    if (antes === "Reembolso") {
      out.push({ sheet: alvo.nome, antes: antes, changed: false });
      continue;
    }
    cell.setValue("Reembolso");
    out.push({ sheet: alvo.nome, antes: antes, changed: true });
  }
  return { ok: true, sheets: out };
}
