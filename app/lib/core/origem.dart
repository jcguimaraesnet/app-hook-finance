// Spec: docs/specs/data/despesas-sheet.md (col E)
// Mudanças aqui DEVEM começar pela spec.

const String kOrigemCredito = 'Crédito';
const String kOrigemDebito = 'Débito';

const List<String> kOrigens = [kOrigemCredito, kOrigemDebito];

const Map<String, String> _legado = {
  'Cartão': kOrigemCredito,
  'Pix (contas)': kOrigemDebito,
  'Contas': kOrigemDebito,
  'Empregados': kOrigemDebito,
  'Pessoal': kOrigemDebito,
};

/// Converte o enum pré-2026-09-20 na leitura. Vale para linha ainda não migrada
/// e para o intervalo entre publicar o app e rodar a migração — sem isso toda
/// tela filtra por "Crédito" contra dado que ainda diz "Cartão" e mostra zero.
///
/// Ponte temporária: sai quando a planilha não tiver mais valor legado.
/// Valor desconhecido passa intacto, para aparecer na UI em vez de sumir.
String normalizeOrigem(String raw) {
  final v = raw.trim();
  if (v.isEmpty) return '';
  return _legado[v] ?? v;
}
