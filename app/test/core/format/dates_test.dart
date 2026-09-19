import 'package:flutter_test/flutter_test.dart';
import 'package:hook_finance/core/format/dates.dart';

void main() {
  group('parseBrDate', () {
    test('parseia DD/MM/YYYY', () {
      final d = parseBrDate('06/05/2026');
      expect(d.year, 2026);
      expect(d.month, 5);
      expect(d.day, 6);
    });

    test('retorna epoch zero para formato inválido', () {
      expect(parseBrDate(''), DateTime.fromMillisecondsSinceEpoch(0));
      expect(parseBrDate('2026-05-06'), DateTime.fromMillisecondsSinceEpoch(0));
    });
  });

  group('parseBrRefDate', () {
    test('col B com hora mantém ano, dia e horário', () {
      final d = parseBrRefDate('18/09/2026 18:17');
      expect(d, DateTime(2026, 9, 18, 18, 17));
    });

    test('col B sem hora (webhook) vira meia-noite do dia certo', () {
      expect(parseBrRefDate('18/09/2026'), DateTime(2026, 9, 18));
    });

    test('ordena a fatura que cruza o ano', () {
      final refs = ['20/12/2025 10:00', '05/01/2026 09:00', '02/01/2026 08:00']
        ..sort((a, b) => parseBrRefDate(b).compareTo(parseBrRefDate(a)));
      expect(refs, [
        '05/01/2026 09:00',
        '02/01/2026 08:00',
        '20/12/2025 10:00',
      ]);
    });

    test('desempata pelo horário no mesmo dia', () {
      final refs = ['18/09/2026 08:00', '18/09/2026 21:30']
        ..sort((a, b) => parseBrRefDate(b).compareTo(parseBrRefDate(a)));
      expect(refs.first, '18/09/2026 21:30');
    });

    test('hora malformada não descarta a data', () {
      expect(parseBrRefDate('18/09/2026 xx:yy'), DateTime(2026, 9, 18));
      expect(parseBrRefDate('18/09/2026 1817'), DateTime(2026, 9, 18));
    });

    test('vazio continua epoch zero (ordena por último)', () {
      expect(parseBrRefDate(''), DateTime.fromMillisecondsSinceEpoch(0));
    });
  });

  group('monthYearLabel', () {
    test('converte para nome do mês em pt-BR', () {
      expect(monthYearLabel('06/05/2026'), 'maio de 2026');
      expect(monthYearLabel('01/01/2026'), 'janeiro de 2026');
      expect(monthYearLabel('31/12/2026'), 'dezembro de 2026');
    });

    test("vazio retorna ''", () {
      expect(monthYearLabel(''), '');
      expect(monthYearLabel(null), '');
    });
  });

  group('brDateToMMYYYY', () {
    test('extrai MM/YYYY de DD/MM/YYYY', () {
      expect(brDateToMMYYYY('06/05/2026'), '05/2026');
      expect(brDateToMMYYYY('31/12/2025'), '12/2025');
    });

    test('formato inválido retorna a string original', () {
      expect(brDateToMMYYYY(''), '');
      expect(brDateToMMYYYY('abc'), 'abc');
    });
  });

  group('parseBrDateTime', () {
    test('parseia DD/MM/YYYY HH:MM', () {
      final d = parseBrDateTime('11/05/2026 14:32');
      expect(d.year, 2026);
      expect(d.month, 5);
      expect(d.day, 11);
      expect(d.hour, 14);
      expect(d.minute, 32);
    });

    test('retorna epoch zero para formato inválido', () {
      expect(parseBrDateTime(''), DateTime.fromMillisecondsSinceEpoch(0));
      expect(parseBrDateTime('11/05/2026'),
          DateTime.fromMillisecondsSinceEpoch(0));
      expect(parseBrDateTime('2026-05-11T14:32'),
          DateTime.fromMillisecondsSinceEpoch(0));
    });
  });

  group('formatBrDate', () {
    test('formata DateTime para DD/MM/YYYY', () {
      expect(formatBrDate(DateTime(2026, 5, 11)), '11/05/2026');
      expect(formatBrDate(DateTime(2026, 1, 9)), '09/01/2026');
      expect(formatBrDate(DateTime(2026, 12, 31)), '31/12/2026');
    });
  });

  group('formatBrDateTime', () {
    test('formata DateTime para DD/MM/YYYY HH:MM', () {
      expect(formatBrDateTime(DateTime(2026, 5, 11, 14, 32)),
          '11/05/2026 14:32');
      expect(formatBrDateTime(DateTime(2026, 1, 9, 7, 5)),
          '09/01/2026 07:05');
    });
  });

  group('relativeTime', () {
    test('< 1 min => agora', () {
      final now = DateTime.now();
      expect(relativeTime(now.subtract(const Duration(seconds: 20))), 'agora');
    });

    test('minutos', () {
      final now = DateTime.now();
      expect(relativeTime(now.subtract(const Duration(minutes: 5))), 'há 5 min');
    });

    test('horas', () {
      final now = DateTime.now();
      expect(relativeTime(now.subtract(const Duration(hours: 3))), 'há 3h');
    });

    test('dias', () {
      final now = DateTime.now();
      expect(relativeTime(now.subtract(const Duration(days: 2))), 'há 2d');
    });
  });

  group('monthNamePt', () {
    test('retorna nome capitalizado em pt-BR', () {
      expect(monthNamePt(1), 'Janeiro');
      expect(monthNamePt(5), 'Maio');
      expect(monthNamePt(12), 'Dezembro');
    });

    test('fora do range retorna fallback', () {
      expect(monthNamePt(0), 'mês 0');
      expect(monthNamePt(13), 'mês 13');
    });
  });
}
