// Pill bar com 5 itens (Início · Compart · Lançamentos · Histórico · Acerto).
// O ativo tem fundo gradient violet18 → mint18 e texto/ícone violet.

import 'package:flutter/material.dart';
import '../../theme/bloom_colors.dart';
import '../../theme/bloom_typography.dart';

enum BloomTab { inicio, compart, lancamento, historico, acerto }

class BloomBottomNav extends StatelessWidget {
  final BloomTab active;
  final ValueChanged<BloomTab> onChange;

  const BloomBottomNav({
    super.key,
    required this.active,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: BloomColors.card,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: BloomColors.border, width: 1),
            boxShadow: [
              BoxShadow(
                color: BloomColors.violet.withValues(alpha: 0.12),
                blurRadius: 30,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Row(
            children: [
              _NavItem(
                tab: BloomTab.inicio,
                label: 'Início',
                icon: _Icon.home,
                active: active == BloomTab.inicio,
                onTap: () => onChange(BloomTab.inicio),
              ),
              _NavItem(
                tab: BloomTab.compart,
                label: 'Categoria',
                icon: _Icon.shared,
                active: active == BloomTab.compart,
                onTap: () => onChange(BloomTab.compart),
              ),
              _NavItem(
                tab: BloomTab.lancamento,
                label: 'Lançamentos',
                icon: _Icon.list,
                active: active == BloomTab.lancamento,
                onTap: () => onChange(BloomTab.lancamento),
              ),
              _NavItem(
                tab: BloomTab.historico,
                label: 'Histórico',
                icon: _Icon.chart,
                active: active == BloomTab.historico,
                onTap: () => onChange(BloomTab.historico),
              ),
              _NavItem(
                tab: BloomTab.acerto,
                label: 'Acerto',
                icon: _Icon.split,
                active: active == BloomTab.acerto,
                onTap: () => onChange(BloomTab.acerto),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _Icon { home, shared, list, chart, split }

class _NavItem extends StatelessWidget {
  final BloomTab tab;
  final String label;
  final _Icon icon;
  final bool active;
  final VoidCallback onTap;

  const _NavItem({
    required this.tab,
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? BloomColors.violet : BloomColors.inkSoft;
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.fromLTRB(0, 7, 0, 5),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: active
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        BloomColors.violet.withValues(alpha: 0.094),
                        BloomColors.mint.withValues(alpha: 0.094),
                      ],
                    )
                  : null,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _NavIcon(icon: icon, color: color, size: 21),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: BloomTypography.geist(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w500,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavIcon extends StatelessWidget {
  final _Icon icon;
  final Color color;
  final double size;

  const _NavIcon({
    required this.icon,
    required this.color,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final material = switch (icon) {
      _Icon.home => Icons.home_outlined,
      _Icon.shared => Icons.credit_card_outlined,
      _Icon.list => Icons.list_alt_outlined,
      _Icon.chart => Icons.show_chart,
      _Icon.split => Icons.swap_horiz_outlined,
    };
    return Icon(material, color: color, size: size);
  }
}
