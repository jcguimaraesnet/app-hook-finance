// Spec: docs/specs/state/persistence.md
// Spec: docs/specs/api/endpoints.md
// Equivalente Flutter dos hooks Tanstack Query do PWA. Cache via Riverpod.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/rules/bucket_deltas.dart';
import '../core/types.dart';
import 'auth_provider.dart';

/// Mês atualmente selecionado no StickyHeader. Sessão (não persistido).
final currentMonthProvider = StateProvider<String?>((_) => null);

/// Lista de meses disponíveis (descendente). Recarregado a cada sessão.
final allMonthsProvider = StateProvider<List<String>>((_) => const []);

/// Toggle do Pix do Júlio em Acerto. Quando true, expande mostrando todas as
/// Pix dele (não filtra por `acerto == 'Sim'`). Sessão.
final acertoPixJulioProvider = StateProvider<bool>((_) => false);

/// monthData(month) — equivale a queryKey ["monthData", month].
final monthDataProvider =
    FutureProvider.family<MonthDataResponse, String?>((ref, month) async {
  final api = ref.watch(apiProvider);
  return api.getMonthData(month: month);
});

/// historicalSummary — staleTime 5min equivalente via keepAlive curto.
final historicalSummaryProvider =
    FutureProvider<HistoricalSummaryResponse>((ref) async {
  final api = ref.watch(apiProvider);
  final result = await api.getHistoricalSummary();
  // Cache 5 min: o provider é mantido por 5min mesmo sem listener.
  final link = ref.keepAlive();
  Future.delayed(const Duration(minutes: 5), link.close);
  return result;
});

/// lastEntries(n) — equivale a queryKey ["lastEntries", n].
final lastEntriesProvider =
    FutureProvider.family<LastEntriesResponse, int>((ref, n) async {
  final api = ref.watch(apiProvider);
  return api.getLastEntries(n: n);
});

/// despesas-fixas — aba de configuração, muda raramente.
final fixedExpensesProvider =
    FutureProvider<FixedExpensesResponse>((ref) async {
  final api = ref.watch(apiProvider);
  return api.getFixedExpenses();
});

/// Helper para invalidar caches após mutation (equivalente ao queryClient.invalidateQueries).
void invalidateAfterMutation(Ref ref) {
  ref.invalidate(monthDataProvider);
  ref.invalidate(lastEntriesProvider);
}

/// Mês anterior ao `currentMonth` (formato `MM/YYYY`). `null` se indeterminado.
final previousMonthProvider = Provider<String?>((ref) {
  final cur = ref.watch(currentMonthProvider);
  return previousMonthOf(cur);
});

/// Atalho para `monthData(previousMonth)`.
final previousMonthDataProvider =
    FutureProvider<MonthDataResponse?>((ref) async {
  final prev = ref.watch(previousMonthProvider);
  if (prev == null) return null;
  // Reusa o cache via `monthDataProvider(prev)`.
  final api = ref.watch(apiProvider);
  return api.getMonthData(month: prev);
});
