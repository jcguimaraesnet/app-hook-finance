// Donut clicável (3 arcos compart/pessoal/contas) com label central reativo.
// Spec: docs/specs/pages/inicio.md (donut interativo).

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../theme/bloom_colors.dart';
import '../../theme/bloom_typography.dart';

class DonutBucket {
  final String label;
  final double value;
  final double pct;
  const DonutBucket(
      {required this.label, required this.value, required this.pct});
}

class BloomDonut extends StatelessWidget {
  final List<DonutBucket> buckets;
  final double total;
  final String person;
  final List<Color>? colors;
  final int? selectedIdx;
  final ValueChanged<int?> onSelect;
  final double size;
  final double stroke;

  const BloomDonut({
    super.key,
    required this.buckets,
    required this.total,
    required this.person,
    this.colors,
    required this.selectedIdx,
    required this.onSelect,
    this.size = 170,
    this.stroke = 18,
  });

  /// Cores dos arcos, na ordem de `buckets`. Vem de quem monta os buckets — a
  /// legenda ao lado usa a mesma lista. Quando esta lista era fixa aqui dentro,
  /// reordenar as fatias pintou Pessoal de azul e Débito de verde, com a
  /// legenda mostrando o contrário.
  static const _coresPadrao = [
    BloomColors.violet,
    BloomColors.mint,
    BloomColors.sky,
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) {
              final hit = _hitTest(d.localPosition);
              onSelect(hit == selectedIdx ? null : hit);
            },
            child: CustomPaint(
              size: Size.square(size),
              painter: _DonutPainter(
                buckets: buckets,
                colors: colors ?? _coresPadrao,
                stroke: stroke,
                selectedIdx: selectedIdx,
              ),
            ),
          ),
          IgnorePointer(
            child: Text(
              person,
              style: BloomTypography.display(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.4,
                height: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Determina qual arco foi tocado, ou `null` se foi fora do donut.
  int? _hitTest(Offset local) {
    final c = Offset(size / 2, size / 2);
    final dx = local.dx - c.dx;
    final dy = local.dy - c.dy;
    final dist = math.sqrt(dx * dx + dy * dy);
    final r = (size - stroke) / 2;
    final inner = r - stroke / 2 - 4;
    final outer = r + stroke / 2 + 4;
    if (dist < inner || dist > outer) return null;

    // Ângulo do toque a partir do topo, em sentido horário, [0, 2π).
    final raw = math.atan2(dy, dx); // [-π, π], 0 = leste
    var fromTop = raw + math.pi / 2;
    if (fromTop < 0) fromTop += 2 * math.pi;
    final pctAt = fromTop / (2 * math.pi) * 100;

    var acc = 0.0;
    for (var i = 0; i < buckets.length; i++) {
      final start = acc;
      final end = acc + buckets[i].pct;
      if (pctAt >= start && pctAt < end) return i;
      acc = end;
    }
    return null;
  }
}

class _DonutPainter extends CustomPainter {
  final List<DonutBucket> buckets;
  final List<Color> colors;
  final double stroke;
  final int? selectedIdx;

  _DonutPainter({
    required this.buckets,
    required this.colors,
    required this.stroke,
    required this.selectedIdx,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = (size.width - stroke) / 2;
    final rect = Rect.fromCircle(center: c, radius: r);

    // Trilho de fundo (anel completo).
    final track = Paint()
      ..color = BloomColors.divider
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    canvas.drawCircle(c, r, track);

    // Gap angular (em radianos) entre cada arco — corresponde a ~3px de arco.
    final gap = 3 / r;
    var startAngle = -math.pi / 2;

    for (var i = 0; i < buckets.length; i++) {
      final pct = buckets[i].pct.clamp(0.0, 100.0);
      var sweep = pct / 100 * 2 * math.pi - gap;
      if (sweep < 0) sweep = 0;

      final isSel = selectedIdx == i;
      final dim = selectedIdx != null && !isSel;
      final color = colors[i].withValues(alpha: dim ? 0.35 : 1.0);

      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = isSel ? stroke + 4 : stroke
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(rect, startAngle, sweep, false, paint);
      startAngle += sweep + gap;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) =>
      old.buckets != buckets ||
      old.selectedIdx != selectedIdx ||
      old.stroke != stroke;
}
