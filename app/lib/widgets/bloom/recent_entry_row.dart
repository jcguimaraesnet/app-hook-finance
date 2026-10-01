// Spec: docs/specs/cards/recent-entry-row.md

import 'package:flutter/material.dart';
import '../../core/format/money.dart';
import '../../core/rateio.dart';
import '../../core/types.dart';
import '../../theme/bloom_colors.dart';
import '../../theme/bloom_typography.dart';

class RecentEntryRow extends StatelessWidget {
  final ExpenseRow entry;
  final VoidCallback? onTap;
  final bool showDivider;
  /// Quando true e o entry tem categoria ou rateio vazios, destaca em vermelho.
  final bool highlightMissing;
  /// Quando true, suprime também a categoria da 2ª linha. Usado em telas onde
  /// a categoria não acrescenta info (ex.: Despesas pessoais, lista estreita).
  final bool hideCategory;

  const RecentEntryRow({
    super.key,
    required this.entry,
    this.onTap,
    this.showDivider = true,
    this.highlightMissing = false,
    this.hideCategory = false,
  });

  @override
  Widget build(BuildContext context) {
    final missing = highlightMissing &&
        (entry.categoria.isEmpty || entry.rateio.isEmpty);
    final tone = missing ? BloomColors.bad : _toneFor(entry.rateio);
    final descColor = missing ? BloomColors.bad : BloomColors.ink;
    final avatarLabel = _avatarLabel(entry.rateio);

    final rawDateRef = entry.dataRef.isNotEmpty ? entry.dataRef : entry.data;
    // Data sai da meta-linha e vai para a direita da descrição, em DD/MM — a
    // meta ficava com três informações disputando uma linha de 10px.
    final diaMes = _diaMes(_stripTime(rawDateRef));
    final cat = entry.categoria.isEmpty ? '—' : entry.categoria;
    final parcelaSuffix = _parcelaSuffix(entry.parcela);
    // parcelaSuffix já vem com " · " na frente; sem categoria antes, sobra o
    // separador solto.
    final meta = hideCategory
        ? parcelaSuffix.replaceFirst(' · ', '')
        : '$cat$parcelaSuffix';
    final metaStyle = BloomTypography.mono(
      fontSize: 10,
      color: BloomColors.muted,
    );

    final row = Row(
      children: [
        Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: tone.withValues(alpha: 0.13),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(
            avatarLabel,
            style: BloomTypography.display(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: tone,
              height: 1,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Flexible(
                    child: Text(
                      entry.descricao.isEmpty ? '—' : entry.descricao,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: BloomTypography.geist(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: descColor,
                      ),
                    ),
                  ),
                  if (diaMes.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Text(diaMes, style: metaStyle),
                  ],
                ],
              ),
              if (meta.isNotEmpty) ...[
                const SizedBox(height: 1),
                Text(
                  meta,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: metaStyle,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 10),
        Text(
          'R\$ ${formatMoney(entry.valor)}',
          style: BloomTypography.mono(
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        if (onTap != null) ...[
          const SizedBox(width: 6),
          const Icon(Icons.chevron_right,
              size: 14, color: BloomColors.muted),
        ],
      ],
    );

    final padded = Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: row,
    );

    final content = showDivider
        ? Container(
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: BloomColors.divider, width: 1),
              ),
            ),
            child: padded,
          )
        : padded;

    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: content,
      ),
    );
  }

  Color _toneFor(String rateio) {
    if (rateio == kRateioCompartilhado || rateio.isEmpty) {
      return BloomColors.neutral;
    }
    if (rateio == 'Dani') return BloomColors.forPerson(Person.dani);
    if (rateio == 'Julio') return BloomColors.forPerson(Person.julio);
    return BloomColors.amber;
  }

  String _avatarLabel(String rateio) {
    if (rateio == kRateioCompartilhado) return '½';
    if (rateio.isEmpty) return '?';
    return rateio.characters.first.toUpperCase();
  }

  String _parcelaSuffix(String parcela) {
    final s = parcela.trim();
    if (s.isEmpty || !s.contains('/')) return '';
    final parts = s.split('/');
    if (parts.length != 2) return '';
    final x = int.tryParse(parts[0]);
    final y = int.tryParse(parts[1]);
    if (x == null || y == null || y <= 0) return '';
    return ' · ($x / $y)';
  }

  /// "30/09/2026" -> "30/09". Formato inesperado passa intacto.
  String _diaMes(String brDate) {
    final parts = brDate.split('/');
    if (parts.length < 2) return brDate;
    return '${parts[0]}/${parts[1]}';
  }

  String _stripTime(String s) {
    final i = s.indexOf(' ');
    return i < 0 ? s : s.substring(0, i);
  }
}
