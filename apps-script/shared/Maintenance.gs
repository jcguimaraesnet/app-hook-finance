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
