// Spec: docs/specs/pages/despesas-fixas.md (modal)
// Spec: docs/specs/data/despesas-fixas-sheet.md (validação das 7 colunas)

import 'package:flutter/material.dart';
import '../../api/endpoints.dart';
import '../../core/origem.dart';
import '../../core/types.dart';

// Diferente da col G da aba Despesas, aqui rateio vazio NÃO é aceito: a linha
// vira lançamento de verdade na Nova fatura e ficaria sem dono.
const List<String> _rateioOptions = ['Julio', 'Dani', 'Metade', 'Alzira'];

/// Valor a enviar no save. Campo intocado devolve o valor original em vez do
/// texto reparseado: a aba tem dízimas (parcela 6x = 379.1666666666667) e o
/// campo mostra 2 casas, então abrir e salvar sem mexer no valor arredondaria
/// silenciosamente. `double.nan` quando o texto editado não é número.
double valorParaEnviar({
  required String textoAtual,
  required String textoInicial,
  required double original,
}) {
  if (textoAtual == textoInicial && !original.isNaN) return original;
  final raw = textoAtual.trim().replaceAll('.', '').replaceAll(',', '.');
  return double.tryParse(raw) ?? double.nan;
}

class FixedExpenseDialog extends StatefulWidget {
  /// `null` = criar. A aba não tem "linha nova" até salvar.
  final FixedExpense? entry;
  final ApiEndpoints api;

  const FixedExpenseDialog({super.key, required this.entry, required this.api});

  @override
  State<FixedExpenseDialog> createState() => _FixedExpenseDialogState();
}

class _FixedExpenseDialogState extends State<FixedExpenseDialog> {
  late final TextEditingController _diaCtrl;
  late final TextEditingController _descricaoCtrl;
  late final TextEditingController _valorCtrl;
  late final TextEditingController _categoriaCtrl;
  late String _origem;
  late String _rateio;
  late bool _acerto;

  /// Valor exato como veio da planilha, e o texto inicial do campo. A aba tem
  /// dízimas (parcela 6x = 379.1666666666667) e o campo mostra 2 casas; sem
  /// isso, abrir e salvar sem tocar no valor o arredondaria silenciosamente.
  late final double _valorOriginal;
  late final String _valorTextoInicial;
  bool _busy = false;
  String? _error;

  bool get _isNew => widget.entry == null;

  @override
  void initState() {
    super.initState();
    final e = widget.entry;
    _diaCtrl = TextEditingController(
      text: (e?.dia ?? 0) > 0 ? '${e!.dia}' : '',
    );
    _descricaoCtrl = TextEditingController(text: e?.descricao ?? '');
    _valorOriginal = e?.valor ?? double.nan;
    _valorTextoInicial =
        e == null ? '' : e.valor.toStringAsFixed(2).replaceAll('.', ',');
    _valorCtrl = TextEditingController(text: _valorTextoInicial);
    _categoriaCtrl = TextEditingController(text: e?.categoria ?? 'Contas');
    _origem = kOrigens.contains(e?.origem) ? e!.origem : kOrigemDebito;
    _rateio = _rateioOptions.contains(e?.rateio) ? e!.rateio : 'Metade';
    _acerto = e?.acerto == 'Sim';
  }

  @override
  void dispose() {
    _diaCtrl.dispose();
    _descricaoCtrl.dispose();
    _valorCtrl.dispose();
    _categoriaCtrl.dispose();
    super.dispose();
  }

  double _readValor() => valorParaEnviar(
        textoAtual: _valorCtrl.text,
        textoInicial: _valorTextoInicial,
        original: _valorOriginal,
      );

  Map<String, dynamic>? _fields() {
    final dia = int.tryParse(_diaCtrl.text.trim());
    if (dia == null || dia < 1 || dia > 31) {
      setState(() => _error = 'Dia precisa ser um número de 1 a 31.');
      return null;
    }
    final descricao = _descricaoCtrl.text.trim();
    if (descricao.isEmpty) {
      setState(() => _error = 'Descrição não pode ficar vazia.');
      return null;
    }
    final valor = _readValor();
    if (valor.isNaN) {
      setState(() => _error = 'Valor inválido.');
      return null;
    }
    final categoria = _categoriaCtrl.text.trim();
    if (categoria.isEmpty) {
      setState(() => _error = 'Categoria não pode ficar vazia.');
      return null;
    }
    return {
      'dia': dia,
      'descricao': descricao,
      'valor': valor,
      'origem': _origem,
      'categoria': categoria,
      'rateio': _rateio,
      'acerto': _acerto ? 'Sim' : '',
    };
  }

  Future<void> _save() async {
    setState(() => _error = null);
    final fields = _fields();
    if (fields == null) return;

    setState(() => _busy = true);
    try {
      final r = _isNew
          ? await widget.api.addFixedExpense(fields)
          : await widget.api.updateFixedExpense(widget.entry!.row, fields);
      if (!mounted) return;
      if (r.ok) {
        Navigator.of(context).pop(true);
      } else {
        // O backend devolve `detail` com o motivo exato (mesmo texto que o
        // webhook usaria); mostrar só "invalid_fields" esconderia o que corrigir.
        setState(() => _error = r.detail ?? r.error ?? 'Erro');
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
        title: const Text('Excluir despesa fixa?'),
        content: const Text(
          'Ela deixa de entrar nas próximas faturas. '
          'Lançamentos já criados não são afetados.',
        ),
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
      final r = await widget.api.deleteFixedExpense(widget.entry!.row);
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
                      _isNew ? 'Nova despesa fixa' : 'Editar despesa fixa',
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                  if (!_isNew)
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      color: theme.colorScheme.error,
                      tooltip: 'Excluir',
                      onPressed: _busy ? null : _delete,
                    ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: _diaCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Dia',
                              helperText: '1 a 31',
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 3,
                          child: TextField(
                            controller: _valorCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration:
                                const InputDecoration(labelText: 'Valor (R\$)'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _descricaoCtrl,
                      decoration: const InputDecoration(labelText: 'Descrição'),
                      autocorrect: false,
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _categoriaCtrl,
                      decoration: const InputDecoration(labelText: 'Categoria'),
                      autocorrect: false,
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: _origem,
                      decoration: const InputDecoration(labelText: 'Origem'),
                      items: [
                        for (final o in kOrigens)
                          DropdownMenuItem(value: o, child: Text(o)),
                      ],
                      onChanged: _busy
                          ? null
                          : (v) => setState(() => _origem = v ?? kOrigemDebito),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: _rateio,
                      decoration: const InputDecoration(labelText: 'Rateio'),
                      items: [
                        for (final r in _rateioOptions)
                          DropdownMenuItem(
                            value: r,
                            child: Text(
                                r == 'Metade' ? 'Metade (compartilhado)' : r),
                          ),
                      ],
                      onChanged:
                          _busy ? null : (v) => setState(() => _rateio = v ?? 'Metade'),
                    ),
                    const SizedBox(height: 4),
                    SwitchListTile(
                      value: _acerto,
                      onChanged:
                          _busy ? null : (v) => setState(() => _acerto = v),
                      title: const Text('Entra no acerto'),
                      subtitle: const Text('Grava "Sim" na coluna Acerto'),
                      contentPadding: EdgeInsets.zero,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 8),
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
                    onPressed:
                        _busy ? null : () => Navigator.of(context).pop(false),
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
