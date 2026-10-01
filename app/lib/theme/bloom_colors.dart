// Spec: docs/specs/conventions.md
// Tokens visuais da direção Bloom — espelha o objeto BLOOM em direction-bloom.jsx.

import 'package:flutter/material.dart';
import '../core/types.dart';

class BloomColors {
  BloomColors._();

  // Backgrounds
  static const bg1 = Color(0xFFF0EEFF);
  static const bg2 = Color(0xFFE2F4EF);
  static const bg3 = Color(0xFFFBF7FF);

  // Foregrounds
  static const ink = Color(0xFF13123A);
  static const inkSoft = Color(0xFF3A3873);
  static const muted = Color(0xFF7B7AA8);
  // Cinza neutro (sem viés violeta de `muted`). Usado em avatares de rateio
  // "Compartilhado" pra contrastar claramente com o lilás da Dani.
  static const neutral = Color(0xFF8E8E96);

  // Surfaces
  static const card = Colors.white;
  static const border = Color(0x1413123A); // rgba(19,18,58,0.08)
  static const divider = Color(0x0F13123A); // rgba(19,18,58,0.06)

  // Accents
  static const violet = Color(0xFF6E5CE7);
  static const mint = Color(0xFF3FB793);
  static const sky = Color(0xFF5DA7F2);
  static const pink = Color(0xFFEE7BB8);
  static const amber = Color(0xFFF2B441);

  // Semantic
  static const good = Color(0xFF3FB793);
  static const bad = Color(0xFFE16071);

  // Chips e trilhos do redesenho da Início (2026-10-01). Tints sólidos, não
  // alpha: sobre o gradient da tela o alpha deixava o fundo vazar e cada card
  // ficava de um tom.
  static const violetTint = Color(0xFFECE9FF);
  static const violetDeep = Color(0xFF4B37C9);
  static const mintTint = Color(0xFFE2F6EE);
  static const mintDeep = Color(0xFF16714F);
  static const track = Color(0xFFF3F1FA);
  static const soft = Color(0xFFF7F6FC);

  // Background gradient da tela inteira (lavanda → off-white → menta).
  static const screenGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [bg1, bg3, bg2],
    stops: [0.0, 0.4, 1.0],
  );

  // Spec: docs/specs/pages/inicio.md (seção "Cores por pessoa")
  static Color forPerson(Person p) {
    switch (p) {
      case Person.julio:
        return mint;
      case Person.dani:
        return violet;
    }
  }
}

/// Helper: aplica opacidade a uma cor base como `mint.withAlpha(0x33)` mas
/// usando hex de 2 dígitos no estilo do JSX (ex: `BLOOM.violet+'18'`).
Color bloomAlpha(Color base, int hex) =>
    base.withAlpha(hex.clamp(0, 255));
