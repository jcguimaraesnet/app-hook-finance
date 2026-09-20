// Spec: docs/specs/api/endpoints.md

import '../core/types.dart';
import 'client.dart';

class ApiEndpoints {
  final ApiClient _client;

  ApiEndpoints(this._client);

  Future<MonthDataResponse> getMonthData({String? month}) async {
    final r = await _client.get(
      'monthData',
      params: {'month': ?month},
    );
    return MonthDataResponse.fromJson(r);
  }

  Future<HistoricalSummaryResponse> getHistoricalSummary() async {
    final r = await _client.get('historicalSummary');
    return HistoricalSummaryResponse.fromJson(r);
  }

  Future<LastEntriesResponse> getLastEntries({int n = 10}) async {
    final r = await _client.get('lastEntries', params: {'n': n});
    return LastEntriesResponse.fromJson(r);
  }

  // Spec: docs/specs/api/endpoints.md (despesas fixas)
  Future<FixedExpensesResponse> getFixedExpenses() async {
    final r = await _client.get('fixedExpenses');
    return FixedExpensesResponse.fromJson(r);
  }

  Future<MutationResponse> addFixedExpense(Map<String, dynamic> fields) async {
    final r = await _client.post('addFixedExpense', {'fields': fields});
    return MutationResponse.fromJson(r);
  }

  Future<MutationResponse> updateFixedExpense(
    int row,
    Map<String, dynamic> fields,
  ) async {
    final r = await _client.post('updateFixedExpense', {
      'row': row,
      'fields': fields,
    });
    return MutationResponse.fromJson(r);
  }

  Future<MutationResponse> deleteFixedExpense(int row) async {
    final r = await _client.post('deleteFixedExpense', {'row': row});
    return MutationResponse.fromJson(r);
  }

  Future<MutationResponse> addEntry(AddEntryFields fields) async {
    final r = await _client.post('addEntry', {'fields': fields.toJson()});
    return MutationResponse.fromJson(r);
  }

  Future<MutationResponse> updateEntry(int row, UpdateEntryFields fields) async {
    final r = await _client.post('updateEntry', {
      'row': row,
      'fields': fields.toJson(),
    });
    return MutationResponse.fromJson(r);
  }

  Future<MutationResponse> deleteEntry(int row) async {
    final r = await _client.post('deleteEntry', {'row': row});
    return MutationResponse.fromJson(r);
  }

  Future<NewInvoiceResponse> newInvoice() async {
    final r = await _client.post('newInvoice', const {});
    return NewInvoiceResponse.fromJson(r);
  }

  /// Preview read-only da data que `newInvoice()` criaria agora (última fatura
  /// da planilha + 1 mês). Usado pelo dialog de confirmação. Só `invoiceClosing`
  /// vem preenchido — `fixedCount`/`parcelaCount` ficam nulos.
  Future<NewInvoiceResponse> previewNewInvoice() async {
    final r = await _client.get('newInvoicePreview');
    return NewInvoiceResponse.fromJson(r);
  }
}
