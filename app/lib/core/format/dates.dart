// Spec: docs/specs/conventions.md (Datas)

const List<String> _monthNamesPt = [
  'janeiro',
  'fevereiro',
  'março',
  'abril',
  'maio',
  'junho',
  'julho',
  'agosto',
  'setembro',
  'outubro',
  'novembro',
  'dezembro',
];

/// "DD/MM/YYYY" -> DateTime (epoch comparável). Inválido -> DateTime(1970).
DateTime parseBrDate(String s) {
  final parts = s.split('/');
  if (parts.length != 3) return DateTime.fromMillisecondsSinceEpoch(0);
  final d = int.tryParse(parts[0]) ?? 1;
  final m = int.tryParse(parts[1]) ?? 1;
  final y = int.tryParse(parts[2]) ?? 1970;
  return DateTime(y, m, d);
}

/// "06/05/2026" -> "maio de 2026".
String monthYearLabel(String? brDate) {
  if (brDate == null || brDate.isEmpty) return '';
  final parts = brDate.split('/');
  if (parts.length != 3) return brDate;
  final m = int.tryParse(parts[1]) ?? 0;
  final y = parts[2];
  final name = (m >= 1 && m <= 12) ? _monthNamesPt[m - 1] : 'mês $m';
  return '$name de $y';
}

/// "06/05/2026" -> "05/2026". Usado em ticks de eixo X dos gráficos.
String brDateToMMYYYY(String brDate) {
  final parts = brDate.split('/');
  if (parts.length != 3) return brDate;
  return '${parts[1]}/${parts[2]}';
}

const _monthsCapitalizedPt = [
  'Janeiro',
  'Fevereiro',
  'Março',
  'Abril',
  'Maio',
  'Junho',
  'Julho',
  'Agosto',
  'Setembro',
  'Outubro',
  'Novembro',
  'Dezembro',
];

/// Aceita "DD/MM/YYYY" ou "MM/YYYY" e retorna "Mês, YYYY" (pt-BR capitalizado).
/// Ex: "06/05/2026" -> "Maio, 2026"; "05/2026" -> "Maio, 2026".
String monthYearLong(String? raw) {
  if (raw == null || raw.isEmpty) return '—';
  final parts = raw.split('/');
  int? m;
  String? y;
  if (parts.length == 3) {
    m = int.tryParse(parts[1]);
    y = parts[2];
  } else if (parts.length == 2) {
    m = int.tryParse(parts[0]);
    y = parts[1];
  }
  if (m == null || y == null || m < 1 || m > 12) return raw;
  return '${_monthsCapitalizedPt[m - 1]}, $y';
}

/// Aceita "DD/MM/YYYY" ou "MM/YYYY" e retorna "mês de YYYY" (pt-BR lowercase).
/// Ex: "06/05/2026" -> "maio de 2026"; "05/2026" -> "maio de 2026".
String monthYearShort(String? raw) {
  if (raw == null || raw.isEmpty) return '';
  final parts = raw.split('/');
  int? m;
  String? y;
  if (parts.length == 3) {
    m = int.tryParse(parts[1]);
    y = parts[2];
  } else if (parts.length == 2) {
    m = int.tryParse(parts[0]);
    y = parts[1];
  }
  if (m == null || y == null || m < 1 || m > 12) return raw;
  return '${_monthNamesPt[m - 1]} de $y';
}

/// Aceita "DD/MM/YYYY" ou "MM/YYYY" e retorna "MM/YYYY".
String mmYYYY(String? raw) {
  if (raw == null || raw.isEmpty) return '';
  final parts = raw.split('/');
  if (parts.length == 3) return '${parts[1]}/${parts[2]}';
  if (parts.length == 2) return raw;
  return raw;
}

/// Col B (Data Referência) para **ordenação**: aceita "DD/MM/YYYY" e
/// "DD/MM/YYYY HH:MM". A hora entra na comparação quando existe.
///
/// Existe porque nenhum dos dois parsers acima serve para a col B: `parseBrDate`
/// lê "2026 18:17" como ano, falha e cai no fallback 1970 (ordenava certo por
/// mês/dia e errado na fatura que cruza o ano); `parseBrDateTime` exige a hora,
/// que o webhook não grava quando não consegue extrair da notificação — e seu
/// retorno epoch é sentinel de "não escolhido" no EditDialog.
DateTime parseBrRefDate(String s) {
  final parts = s.trim().split(' ');
  final date = parseBrDate(parts[0]);
  if (parts.length < 2) return date;
  final time = parts[1].split(':');
  if (time.length != 2) return date;
  final hh = int.tryParse(time[0]);
  final mm = int.tryParse(time[1]);
  if (hh == null || mm == null) return date;
  return DateTime(date.year, date.month, date.day, hh, mm);
}

/// "DD/MM/YYYY HH:MM" -> DateTime. Inválido -> DateTime(1970).
DateTime parseBrDateTime(String s) {
  final parts = s.split(' ');
  if (parts.length != 2) return DateTime.fromMillisecondsSinceEpoch(0);
  final dateParts = parts[0].split('/');
  final timeParts = parts[1].split(':');
  if (dateParts.length != 3 || timeParts.length != 2) {
    return DateTime.fromMillisecondsSinceEpoch(0);
  }
  final d = int.tryParse(dateParts[0]);
  final m = int.tryParse(dateParts[1]);
  final y = int.tryParse(dateParts[2]);
  final hh = int.tryParse(timeParts[0]);
  final mm = int.tryParse(timeParts[1]);
  if (d == null || m == null || y == null || hh == null || mm == null) {
    return DateTime.fromMillisecondsSinceEpoch(0);
  }
  return DateTime(y, m, d, hh, mm);
}

String _pad2(int n) => n < 10 ? '0$n' : '$n';

/// DateTime -> "DD/MM/YYYY".
String formatBrDate(DateTime d) =>
    '${_pad2(d.day)}/${_pad2(d.month)}/${d.year}';

/// DateTime -> "DD/MM/YYYY HH:MM".
String formatBrDateTime(DateTime d) =>
    '${formatBrDate(d)} ${_pad2(d.hour)}:${_pad2(d.minute)}';

/// Nome do mês em pt-BR capitalizado. 1 = "Janeiro", 12 = "Dezembro".
String monthNamePt(int month) {
  if (month < 1 || month > 12) return 'mês $month';
  return _monthsCapitalizedPt[month - 1];
}

/// DateTime -> "agora" / "há N min" / "há Nh" / "há Nd" (pt-BR).
String relativeTime(DateTime when) {
  final diff = DateTime.now().difference(when);
  if (diff.inMinutes < 1) return 'agora';
  if (diff.inMinutes < 60) return 'há ${diff.inMinutes} min';
  if (diff.inHours < 24) return 'há ${diff.inHours}h';
  return 'há ${diff.inDays}d';
}
