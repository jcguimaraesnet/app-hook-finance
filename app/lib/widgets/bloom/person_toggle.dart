// Toggle Júlio/Dani das telas de drill-down (Despesas pessoais e Contas).
// Difere de PersonPills (Início): sem total, pill ativa na cor da pessoa.
// Spec: docs/specs/pages/detalhe.md, docs/specs/pages/contas.md

import 'package:flutter/material.dart';
import '../../core/types.dart';
import '../../theme/bloom_colors.dart';
import '../../theme/bloom_typography.dart';

class PersonToggle extends StatelessWidget {
  final Person selected;
  final ValueChanged<Person> onChanged;

  const PersonToggle({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < Person.values.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: _ToggleButton(
              person: Person.values[i],
              active: selected == Person.values[i],
              onTap: () => onChanged(Person.values[i]),
            ),
          ),
        ],
      ],
    );
  }
}

class _ToggleButton extends StatelessWidget {
  final Person person;
  final bool active;
  final VoidCallback onTap;

  const _ToggleButton({
    required this.person,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = BloomColors.forPerson(person);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? color : BloomColors.card,
            borderRadius: BorderRadius.circular(14),
            border: active
                ? null
                : Border.all(color: BloomColors.border, width: 1),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.33),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Text(
            person.displayName,
            style: BloomTypography.geist(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: active ? Colors.white : BloomColors.inkSoft,
            ),
          ),
        ),
      ),
    );
  }
}
