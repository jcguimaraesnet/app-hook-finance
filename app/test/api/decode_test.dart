import 'package:flutter_test/flutter_test.dart';
import 'package:hook_finance/api/client.dart';
import 'package:hook_finance/api/config.dart';

void main() {
  final client = ApiClient(const ApiConfig(token: 't'));

  group('decode de resposta do Apps Script', () {
    test('JSON normal passa', () {
      expect(client.decodeForTest('{"ok":true,"rows":[]}'), {'ok': true, 'rows': []});
    });

    test('Map já decodificado passa', () {
      expect(client.decodeForTest({'ok': true}), {'ok': true});
    });

    // Aconteceu em 2026-10-01 ao chamar o proxy várias vezes em sequência: o
    // Google devolveu uma página. Sem este caso, o HTML inteiro ia para a
    // SnackBar dentro da mensagem do FormatException.
    test('HTML vira mensagem legível, não o HTML inteiro', () {
      const html = '<!DOCTYPE html><html lang="en"><head><script>var x=1;</script>';
      Object? erro;
      try {
        client.decodeForTest(html);
      } catch (e) {
        erro = e;
      }
      expect(erro, isA<FormatException>());
      final msg = (erro as FormatException).message;
      expect(msg, contains('página HTML'));
      expect(msg, isNot(contains('DOCTYPE')));
    });

    test('HTML com espaço na frente também é detectado', () {
      expect(() => client.decodeForTest('\n  <html></html>'),
          throwsA(isA<FormatException>()));
    });

    test('string que não é JSON nem HTML ainda falha', () {
      expect(() => client.decodeForTest('nada disso'),
          throwsA(isA<FormatException>()));
    });
  });
}
