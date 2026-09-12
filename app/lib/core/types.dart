// Spec: docs/specs/data/despesas-sheet.md
// Spec: docs/specs/api/endpoints.md

class ExpenseRow {
  final String data;
  final String dataRef;
  final String descricao;
  final double valor;
  final String origem;
  final String categoria;
  final String rateio;
  final String banco; // "Santander" | "Revolut" | "" (legado pode trazer dígitos)
  final String parcela;
  final String acerto;

  const ExpenseRow({
    required this.data,
    required this.dataRef,
    required this.descricao,
    required this.valor,
    required this.origem,
    required this.categoria,
    required this.rateio,
    required this.banco,
    required this.parcela,
    required this.acerto,
  });

  factory ExpenseRow.fromJson(Map<String, dynamic> j) => ExpenseRow(
        data: (j['data'] ?? '') as String,
        dataRef: (j['dataRef'] ?? '') as String,
        descricao: (j['descricao'] ?? '') as String,
        valor: (j['valor'] as num?)?.toDouble() ?? 0.0,
        origem: (j['origem'] ?? '') as String,
        categoria: (j['categoria'] ?? '') as String,
        rateio: (j['rateio'] ?? '') as String,
        banco: (j['banco'] ?? '') as String,
        parcela: (j['parcela'] ?? '') as String,
        acerto: (j['acerto'] ?? '') as String,
      );
}

class Entry extends ExpenseRow {
  final int row;

  const Entry({
    required this.row,
    required super.data,
    required super.dataRef,
    required super.descricao,
    required super.valor,
    required super.origem,
    required super.categoria,
    required super.rateio,
    required super.banco,
    required super.parcela,
    required super.acerto,
  });

  factory Entry.fromJson(Map<String, dynamic> j) => Entry(
        row: (j['row'] as num?)?.toInt() ?? 0,
        data: (j['data'] ?? '') as String,
        dataRef: (j['dataRef'] ?? '') as String,
        descricao: (j['descricao'] ?? '') as String,
        valor: (j['valor'] as num?)?.toDouble() ?? 0.0,
        origem: (j['origem'] ?? '') as String,
        categoria: (j['categoria'] ?? '') as String,
        rateio: (j['rateio'] ?? '') as String,
        banco: (j['banco'] ?? '') as String,
        parcela: (j['parcela'] ?? '') as String,
        acerto: (j['acerto'] ?? '') as String,
      );
}

class MonthDataResponse {
  final bool ok;
  final String? error;
  final String? month;
  final List<ExpenseRow> rows;

  const MonthDataResponse({
    required this.ok,
    this.error,
    this.month,
    this.rows = const [],
  });

  factory MonthDataResponse.fromJson(Map<String, dynamic> j) =>
      MonthDataResponse(
        ok: j['ok'] == true,
        error: j['error'] as String?,
        month: j['month'] as String?,
        rows: (j['rows'] as List?)
                ?.map((e) => ExpenseRow.fromJson(e as Map<String, dynamic>))
                .where((e) => e.data.isNotEmpty || e.descricao.trim().isNotEmpty)
                .toList() ??
            const [],
      );
}

class HistoricalSummary {
  final List<String> months;
  final List<double> totals;
  final List<double> julioPessoal;
  final List<double> daniPessoal;

  const HistoricalSummary({
    required this.months,
    required this.totals,
    required this.julioPessoal,
    required this.daniPessoal,
  });

  factory HistoricalSummary.fromJson(Map<String, dynamic> j) =>
      HistoricalSummary(
        months: ((j['months'] as List?) ?? const []).cast<String>(),
        totals: ((j['totals'] as List?) ?? const [])
            .map((v) => (v as num).toDouble())
            .toList(),
        julioPessoal: ((j['julioPessoal'] as List?) ?? const [])
            .map((v) => (v as num).toDouble())
            .toList(),
        daniPessoal: ((j['daniPessoal'] as List?) ?? const [])
            .map((v) => (v as num).toDouble())
            .toList(),
      );
}

class HistoricalSummaryResponse {
  final bool ok;
  final String? error;
  final List<String> months;
  final HistoricalSummary? history;

  const HistoricalSummaryResponse({
    required this.ok,
    this.error,
    this.months = const [],
    this.history,
  });

  factory HistoricalSummaryResponse.fromJson(Map<String, dynamic> j) =>
      HistoricalSummaryResponse(
        ok: j['ok'] == true,
        error: j['error'] as String?,
        months: ((j['months'] as List?) ?? const []).cast<String>(),
        history: j['history'] is Map<String, dynamic>
            ? HistoricalSummary.fromJson(j['history'] as Map<String, dynamic>)
            : null,
      );
}

class LastEntriesResponse {
  final bool ok;
  final String? error;
  final List<Entry> entries;

  const LastEntriesResponse({
    required this.ok,
    this.error,
    this.entries = const [],
  });

  factory LastEntriesResponse.fromJson(Map<String, dynamic> j) =>
      LastEntriesResponse(
        ok: j['ok'] == true,
        error: j['error'] as String?,
        entries: (j['entries'] as List?)
                ?.map((e) => Entry.fromJson(e as Map<String, dynamic>))
                .where((e) => e.data.isNotEmpty || e.descricao.trim().isNotEmpty)
                .toList() ??
            const [],
      );
}

class UpdateEntryFields {
  final String descricao;
  final double valor;
  final String categoria;
  final String rateio;
  final String parcela;
  final String data;       // "DD/MM/YYYY"
  final String dataRef;    // "DD/MM/YYYY HH:MM"
  final String origem;     // enum
  final String banco;      // "" | "Santander" | "Revolut"

  const UpdateEntryFields({
    required this.descricao,
    required this.valor,
    required this.categoria,
    required this.rateio,
    required this.parcela,
    required this.data,
    required this.dataRef,
    required this.origem,
    required this.banco,
  });

  Map<String, dynamic> toJson() => {
        'descricao': descricao,
        'valor': valor,
        'categoria': categoria,
        'rateio': rateio,
        'parcela': parcela,
        'data': data,
        'dataRef': dataRef,
        'origem': origem,
        'banco': banco,
      };
}

class AddEntryFields {
  final String descricao;
  final double valor;
  final String origem;
  final String? data;
  final String? dataRef;
  final String categoria;
  final String rateio;
  final String banco; // "Santander" | "Revolut" | "" (legado pode trazer dígitos)
  final String parcela;
  final String acerto;

  const AddEntryFields({
    required this.descricao,
    required this.valor,
    required this.origem,
    this.data,
    this.dataRef,
    this.categoria = '',
    this.rateio = '',
    this.banco = '',
    this.parcela = '',
    this.acerto = '',
  });

  Map<String, dynamic> toJson() {
    final m = <String, dynamic>{
      'descricao': descricao,
      'valor': valor,
      'origem': origem,
      'categoria': categoria,
      'rateio': rateio,
      'banco': banco,
      'parcela': parcela,
      'acerto': acerto,
    };
    if (data != null) m['data'] = data;
    if (dataRef != null) m['dataRef'] = dataRef;
    return m;
  }
}

class MutationResponse {
  final bool ok;
  final String? error;
  final int? row;

  const MutationResponse({required this.ok, this.error, this.row});

  factory MutationResponse.fromJson(Map<String, dynamic> j) => MutationResponse(
        ok: j['ok'] == true,
        error: j['error'] as String?,
        row: (j['row'] as num?)?.toInt(),
      );
}

class NewInvoiceResponse {
  final bool ok;
  final String? error;
  final String? detail;
  final String? invoiceClosing;
  final int? fixedCount;
  final int? parcelaCount;

  const NewInvoiceResponse({
    required this.ok,
    this.error,
    this.detail,
    this.invoiceClosing,
    this.fixedCount,
    this.parcelaCount,
  });

  factory NewInvoiceResponse.fromJson(Map<String, dynamic> j) => NewInvoiceResponse(
        ok: j['ok'] == true,
        error: j['error'] as String?,
        detail: j['detail'] as String?,
        invoiceClosing: j['invoiceClosing'] as String?,
        fixedCount: (j['fixedCount'] as num?)?.toInt(),
        parcelaCount: (j['parcelaCount'] as num?)?.toInt(),
      );
}

enum Person { julio, dani }

extension PersonX on Person {
  String get name => switch (this) {
        Person.julio => 'Julio',
        Person.dani => 'Dani',
      };

  String get displayName => switch (this) {
        Person.julio => 'Júlio',
        Person.dani => 'Dani',
      };

  Person get other => switch (this) {
        Person.julio => Person.dani,
        Person.dani => Person.julio,
      };
}
