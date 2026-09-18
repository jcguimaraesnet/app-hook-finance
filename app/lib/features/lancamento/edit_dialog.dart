// Spec: docs/specs/pages/lancamento.md (modal de edição)
// Spec: docs/specs/rules/parcela-format.md (math do total)

import 'package:flutter/material.dart';
import '../../api/endpoints.dart';
import '../../core/format/dates.dart';
import '../../core/format/money.dart';
import '../../core/rules/parcela.dart';
import '../../core/types.dart';
import '../../widgets/bloom/month_year_picker.dart';

const List<String> _origemOptions = [
  'Cartão',
  'Pix (contas)',
  'Pessoal',
  'Empregados',
  'Contas',
];

// Spec: docs/specs/data/despesas-sheet.md (col H, Banco)
const List<String> _bancoOptions = ['', 'Santander', 'Revolut'];

const double _fieldGap = 10;

class EditDialog extends StatefulWidget {
  final Entry entry;
  final List<ExpenseRow> rowsForCategoriaSuggestions;
  final ApiEndpoints api;

  const EditDialog({
    super.key,
    required this.entry,
    required this.rowsForCategoriaSuggestions,
    required this.api,
  });

  @override
  State<EditDialog> createState() => _EditDialogState();
}

class _EditDialogState extends State<EditDialog> {
  late final TextEditingController _descricaoCtrl;
  late final TextEditingController _valorCtrl;
  late final TextEditingController _categoriaCtrl;
  late String _rateio;
  late int _parcela;
  late double _originalTotal;
  late DateTime _data;
  late DateTime _dataRef;
  late String _origem;
  late String _banco;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final e = widget.entry;
    final initialTotal = parcelaTotal(e.parcela);
    _originalTotal = (e.valor) * initialTotal;
    _descricaoCtrl = TextEditingController(text: e.descricao);
    _valorCtrl = TextEditingController(
      text: e.valor.toStringAsFixed(2).replaceAll('.', ','),
    );
    _categoriaCtrl = TextEditingController(text: e.categoria);
    _rateio = e.rateio;
    _parcela = initialTotal;
    _data = parseBrDate(e.data);
    _dataRef = parseBrDateTime(e.dataRef);
    _origem = e.origem;
    _banco = e.banco.trim();
  }

  @override
  void dispose() {
    _descricaoCtrl.dispose();
    _valorCtrl.dispose();
    _categoriaCtrl.dispose();
    super.dispose();
  }

  double _readValor() {
    final raw = _valorCtrl.text.trim().replaceAll('.', '').replaceAll(',', '.');
    return double.tryParse(raw) ?? 0;
  }

  void _adjustParcela(int delta) {
    final next = (_parcela + delta).clamp(1, 99);
    if (next == _parcela) return;
    setState(() {
      _parcela = next;
      final novoValor = _originalTotal / _parcela;
      _valorCtrl.text = novoValor.toStringAsFixed(2).replaceAll('.', ',');
    });
  }

  void _onValorChanged(String _) {
    _originalTotal = _readValor() * _parcela;
    setState(() {});
  }

  Future<void> _pickData() async {
    final picked = await showMonthYearPicker(context, initial: _data);
    if (picked != null && mounted) {
      setState(() => _data = picked);
    }
  }

  Future<void> _pickDataRefDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dataRef.year < 2000 ? DateTime.now() : _dataRef,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked != null && mounted) {
      setState(() {
        _dataRef = DateTime(
          picked.year,
          picked.month,
          picked.day,
          _dataRef.hour,
          _dataRef.minute,
        );
      });
    }
  }

  Future<void> _pickDataRefTime() async {
    final initial = _dataRef.year < 2000
        ? TimeOfDay.now()
        : TimeOfDay(hour: _dataRef.hour, minute: _dataRef.minute);
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
    );
    if (picked != null && mounted) {
      setState(() {
        final base = _dataRef.year < 2000 ? DateTime.now() : _dataRef;
        _dataRef = DateTime(
          base.year,
          base.month,
          base.day,
          picked.hour,
          picked.minute,
        );
      });
    }
  }

  Future<void> _save() async {
    if (_data.year < 2000) {
      setState(() => _error = 'Escolha o Mês Fatura antes de salvar.');
      return;
    }
    if (_dataRef.year < 2000) {
      setState(() => _error = 'Escolha a Data Referência antes de salvar.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final fields = UpdateEntryFields(
        descricao: _descricaoCtrl.text.trim(),
        valor: _readValor(),
        categoria: _categoriaCtrl.text.trim(),
        rateio: _rateio,
        parcela: _parcela > 1 ? '1/$_parcela' : '',
        data: formatBrDate(_data),
        dataRef: formatBrDateTime(_dataRef),
        origem: _origem,
        banco: _origem == 'Cartão' ? _banco : '',
      );
      final r = await widget.api.updateEntry(widget.entry.row, fields);
      if (!mounted) return;
      if (r.ok) {
        Navigator.of(context).pop(true);
      } else {
        setState(() => _error = r.error ?? 'Erro');
      }
    } catch (err) {
      if (mounted) setState(() => _error = err.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Excluir lançamento?'),
        content: const Text('Esta ação não pode ser desfeita.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final r = await widget.api.deleteEntry(widget.entry.row);
      if (!mounted) return;
      if (r.ok) {
        Navigator.of(context).pop(true);
      } else {
        setState(() => _error = r.error ?? 'Erro');
      }
    } catch (err) {
      if (mounted) setState(() => _error = err.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categorias = <String>{
      for (final r in widget.rowsForCategoriaSuggestions)
        if (r.categoria.isNotEmpty) r.categoria,
    }.toList()
      ..sort();

    // Se a origem cru da planilha não está no enum (legado), incluir como item
    // extra com prefixo "(?)" para o usuário corrigir sem perder o valor.
    final origemItems = <String>[..._origemOptions];
    if (_origem.isNotEmpty && !origemItems.contains(_origem)) {
      origemItems.add(_origem);
    }

    // Idem para banco: linhas pré-migração trazem os 4 dígitos do cartão
    // (ex. "784"); mostramos como "(?) 784" até o usuário escolher o banco.
    final bancoItems = <String>[..._bancoOptions];
    if (_banco.isNotEmpty && !bancoItems.contains(_banco)) {
      bancoItems.add(_banco);
    }

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Editar lançamento',
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    color: theme.colorScheme.error,
                    tooltip: 'Excluir lançamento',
                    onPressed: _busy ? null : _delete,
                  ),
                ],
              ),
            ),
            // Só o corpo rola; header e ações ficam fixos para o Salvar nunca
            // sair da viewport em telas baixas.
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _PickerField(
                      label: 'Mês Fatura',
                      value: _data.year < 2000
                          ? '— (toque para escolher)'
                          : monthYearShort(formatBrDate(_data)),
                      onTap: _busy ? null : _pickData,
                    ),
                    const SizedBox(height: _fieldGap),
                    _DataRefField(
                      value: _dataRef,
                      onPickDate: _busy ? null : _pickDataRefDate,
                      onPickTime: _busy ? null : _pickDataRefTime,
                    ),
                    const SizedBox(height: _fieldGap),
                    DropdownButtonFormField<String>(
                      initialValue:
                          origemItems.contains(_origem) ? _origem : null,
                      decoration: const InputDecoration(labelText: 'Origem'),
                      items: [
                        for (final o in origemItems)
                          DropdownMenuItem(
                            value: o,
                            child: Text(
                              _origemOptions.contains(o) ? o : '(?) $o',
                            ),
                          ),
                      ],
                      onChanged: _busy
                          ? null
                          : (v) => setState(() => _origem = v ?? ''),
                    ),
                    const SizedBox(height: _fieldGap),
                    TextField(
                      controller: _descricaoCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Descrição'),
                      autocorrect: false,
                    ),
                    const SizedBox(height: _fieldGap),
                    TextField(
                      controller: _valorCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Valor (R\$)'),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      onChanged: _onValorChanged,
                    ),
                    const SizedBox(height: _fieldGap),
                    _CategoriaField(
                      controller: _categoriaCtrl,
                      options: categorias,
                    ),
                    const SizedBox(height: _fieldGap),
                    DropdownButtonFormField<String>(
                      initialValue: _rateio,
                      decoration: const InputDecoration(labelText: 'Rateio'),
                      items: const [
                        DropdownMenuItem(value: '', child: Text('(vazio)')),
                        DropdownMenuItem(value: 'Julio', child: Text('Julio')),
                        DropdownMenuItem(value: 'Dani', child: Text('Dani')),
                        DropdownMenuItem(
                            value: 'Metade',
                            child: Text('Metade (compartilhado)')),
                        DropdownMenuItem(
                            value: 'Alzira', child: Text('Alzira')),
                      ],
                      onChanged: (v) => setState(() => _rateio = v ?? ''),
                    ),
                    if (_origem == 'Cartão') ...[
                      const SizedBox(height: _fieldGap),
                      DropdownButtonFormField<String>(
                        initialValue:
                            bancoItems.contains(_banco) ? _banco : '',
                        decoration: const InputDecoration(labelText: 'Banco'),
                        items: [
                          for (final b in bancoItems)
                            DropdownMenuItem(
                              value: b,
                              child: Text(
                                b.isEmpty
                                    ? '(vazio)'
                                    : _bancoOptions.contains(b)
                                        ? b
                                        : '(?) $b',
                              ),
                            ),
                        ],
                        onChanged: _busy
                            ? null
                            : (v) => setState(() => _banco = v ?? ''),
                      ),
                    ],
                    const SizedBox(height: _fieldGap),
                    _ParcelaField(
                      parcela: _parcela,
                      originalTotal: _originalTotal,
                      onMinus: () => _adjustParcela(-1),
                      onPlus: () => _adjustParcela(1),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: _fieldGap),
                      Text(
                        'Erro: $_error',
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(
                children: [
                  OutlinedButton(
                    onPressed: _busy
                        ? null
                        : () => Navigator.of(context).pop(false),
                    child: const Text('Cancelar'),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: _busy ? null : _save,
                    child: Text(_busy ? 'Salvando...' : 'Salvar'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoriaField extends StatelessWidget {
  final TextEditingController controller;
  final List<String> options;

  const _CategoriaField({required this.controller, required this.options});

  @override
  Widget build(BuildContext context) {
    return Autocomplete<String>(
      initialValue: TextEditingValue(text: controller.text),
      optionsBuilder: (textValue) {
        if (textValue.text.isEmpty) return options;
        final q = textValue.text.toLowerCase();
        return options.where((o) => o.toLowerCase().contains(q));
      },
      onSelected: (v) => controller.text = v,
      fieldViewBuilder:
          (context, fieldController, focusNode, onFieldSubmitted) {
        fieldController.text = controller.text;
        fieldController.addListener(() {
          if (controller.text != fieldController.text) {
            controller.text = fieldController.text;
          }
        });
        return TextField(
          controller: fieldController,
          focusNode: focusNode,
          decoration: const InputDecoration(labelText: 'Categoria'),
          autocorrect: false,
        );
      },
    );
  }
}

class _ParcelaField extends StatelessWidget {
  final int parcela;
  final double originalTotal;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  const _ParcelaField({
    required this.parcela,
    required this.originalTotal,
    required this.onMinus,
    required this.onPlus,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Parcela',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 6),
        // Total na mesma linha do stepper: economiza uma linha de altura no
        // modal, que precisa caber sem rolagem em telas de celular.
        Row(
          children: [
            FilledButton(
              onPressed: onMinus,
              style: FilledButton.styleFrom(
                shape: const CircleBorder(),
                padding: const EdgeInsets.all(10),
                minimumSize: Size.zero,
              ),
              child: const Text('−', style: TextStyle(fontSize: 18)),
            ),
            const SizedBox(width: 6),
            SizedBox(
              width: 44,
              child: Text(
                '${parcela}x',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 6),
            FilledButton(
              onPressed: onPlus,
              style: FilledButton.styleFrom(
                shape: const CircleBorder(),
                padding: const EdgeInsets.all(10),
                minimumSize: Size.zero,
              ),
              child: const Text('+', style: TextStyle(fontSize: 18)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: 'Total da compra: ',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    TextSpan(
                      text: 'R\$ ${formatMoney(originalTotal)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                textAlign: TextAlign.end,
                maxLines: 2,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PickerField extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback? onTap;

  const _PickerField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: double.infinity,
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF0ECE2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(value, style: theme.textTheme.bodyMedium),
                ),
                const Icon(Icons.calendar_today_outlined, size: 18),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _DataRefField extends StatelessWidget {
  final DateTime value;
  final VoidCallback? onPickDate;
  final VoidCallback? onPickTime;

  const _DataRefField({
    required this.value,
    required this.onPickDate,
    required this.onPickTime,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isInvalid = value.year < 2000;
    final dateLabel = isInvalid ? '—' : formatBrDate(value);
    final timeLabel = isInvalid
        ? '--:--'
        : '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

    Widget chip({
      required IconData icon,
      required String label,
      required VoidCallback? onTap,
    }) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF0ECE2),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.bodyMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final dateChip = chip(
      icon: Icons.calendar_today_outlined,
      label: dateLabel,
      onTap: onPickDate,
    );
    final timeChip = chip(
      icon: Icons.access_time,
      label: timeLabel,
      onTap: onPickTime,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Data Referência',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        // "DD/MM/YYYY" precisa de mais espaço que "HH:MM", daí o 3:2. Só em
        // telas muito estreitas (tela de capa do Galaxy Fold) os chips empilham.
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 200) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  dateChip,
                  const SizedBox(height: 8),
                  timeChip,
                ],
              );
            }
            return Row(
              children: [
                Expanded(flex: 3, child: dateChip),
                const SizedBox(width: 8),
                Expanded(flex: 2, child: timeChip),
              ],
            );
          },
        ),
      ],
    );
  }
}
