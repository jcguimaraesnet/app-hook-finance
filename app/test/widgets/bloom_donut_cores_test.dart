import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hook_finance/theme/bloom_colors.dart';
import 'package:hook_finance/widgets/bloom/bloom_donut.dart';

// Regressão: as cores dos arcos eram fixas dentro do BloomDonut na ordem
// antiga (compart, pessoal, contas). Ao reordenar as fatias para
// Crédito/Débito/Pessoal, o arco de Pessoal saiu azul e o de Débito verde,
// enquanto a legenda ao lado mostrava o contrário. Agora as cores vêm de quem
// monta os buckets — uma fonte só para arco e legenda.
/// O painter é privado; pegamos pelo runtime. O que importa testar é que ele
/// RECEBE as cores — foi justamente isso que faltava quando a lista era fixa
/// dentro dele.
dynamic _painterDoDonut(WidgetTester tester) {
  final painters = tester
      .widgetList<CustomPaint>(find.byType(CustomPaint))
      .map((w) => w.painter)
      .whereType<Object>()
      .where((p) => p.runtimeType.toString().contains('DonutPainter'))
      .toList();
  expect(painters, hasLength(1));
  return painters.single;
}

void main() {
  testWidgets('arcos usam as cores recebidas, na ordem dos buckets',
      (tester) async {
    const cores = [BloomColors.violet, BloomColors.sky, BloomColors.mint];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: BloomDonut(
              buckets: const [
                DonutBucket(label: 'Crédito', value: 10, pct: 10),
                DonutBucket(label: 'Débito', value: 0, pct: 0),
                DonutBucket(label: 'Pessoal', value: 90, pct: 90),
              ],
              total: 100,
              person: 'Dani',
              colors: cores,
              selectedIdx: null,
              onSelect: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final painter = _painterDoDonut(tester);
    expect(painter.colors, cores);
    // A cor da fatia grande (Pessoal) é a mesma da legenda de Pessoal.
    expect(painter.colors[2], BloomColors.mint);
  });

  testWidgets('sem cores explícitas usa o padrão', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: BloomDonut(
              buckets: const [
                DonutBucket(label: 'a', value: 1, pct: 100),
              ],
              total: 1,
              person: 'X',
              selectedIdx: null,
              onSelect: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(_painterDoDonut(tester).colors.first, BloomColors.violet);
  });
}
