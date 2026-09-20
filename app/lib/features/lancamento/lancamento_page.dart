// Spec: docs/specs/pages/lancamento.md
// Lançamentos (Bloom) — 2 tabs: lista (10 últimos) + Novo (form stub).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/format/dates.dart';
import '../../core/origem.dart';
import '../../core/types.dart';
import '../../state/auth_provider.dart';
import '../../state/data_providers.dart';
import '../../theme/bloom_colors.dart';
import '../../theme/bloom_typography.dart';
import '../../widgets/bloom/bloom_card.dart';
import '../../widgets/bloom/month_year_picker.dart';
import '../../widgets/bloom/recent_entry_row.dart';
import '../../widgets/bloom/screen_header.dart';
import 'edit_dialog.dart';

final _editListLimitProvider = StateProvider<int>((_) => 10);

class LancamentoPage extends ConsumerStatefulWidget {
  const LancamentoPage({super.key});

  @override
  ConsumerState<LancamentoPage> createState() => _LancamentoPageState();
}

enum _Tab { edit, novo }

class _LancamentoPageState extends ConsumerState<LancamentoPage> {
  _Tab _tab = _Tab.edit;
  bool _refreshing = false;

  Future<void> _onRefresh() async {
    if (_tab != _Tab.edit) return;
    if (_refreshing) return;
    setState(() => _refreshing = true);
    final messenger = ScaffoldMessenger.of(context);
    final currentLimit = ref.read(_editListLimitProvider);
    ref.invalidate(lastEntriesProvider);
    ref.invalidate(monthDataProvider);
    String? error;
    try {
      await Future.wait<void>([
        ref.read(lastEntriesProvider(currentLimit).future),
        ref.read(monthDataProvider(null).future),
      ]);
    } catch (e) {
      error = '$e';
    }
    if (!mounted) return;
    setState(() => _refreshing = false);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
            error == null ? 'Atualizado' : 'Falha ao atualizar: $error'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        backgroundColor:
            error == null ? BloomColors.ink : BloomColors.bad,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _onRefresh,
      color: BloomColors.violet,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.only(
          bottom: 70 + MediaQuery.of(context).padding.bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const ScreenHeader(title: 'Últimos lançamentos'),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: _TabSwitcher(
                tab: _tab,
                onChange: (t) => setState(() => _tab = t),
              ),
            ),
            const SizedBox(height: 14),
            if (_tab == _Tab.edit)
              const _EditList()
            else
              _NovoForm(onCancel: () => setState(() => _tab = _Tab.edit)),
          ],
        ),
      ),
    );
  }
}

class _TabSwitcher extends StatelessWidget {
  final _Tab tab;
  final ValueChanged<_Tab> onChange;

  const _TabSwitcher({required this.tab, required this.onChange});

  @override
  Widget build(BuildContext context) {
    Widget btn(_Tab t, String label) {
      final active = tab == t;
      return Expanded(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => onChange(t),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 9),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: active ? BloomColors.ink : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                label,
                style: BloomTypography.geist(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  color: active ? Colors.white : BloomColors.inkSoft,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: BloomColors.card,
        border: Border.all(color: BloomColors.border, width: 1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          btn(_Tab.edit, 'Lançamentos'),
          btn(_Tab.novo, '+ Novo'),
        ],
      ),
    );
  }
}

class _EditList extends ConsumerStatefulWidget {
  const _EditList();

  @override
  ConsumerState<_EditList> createState() => _EditListState();
}

class _EditListState extends ConsumerState<_EditList> {
  static const int _step = 10;
  static const int _maxLimit = 100;

  // Cache em memória da última lista entregue pelo backend. Mantida visível
  // durante reload do `lastEntriesProvider(novoLimit)` — evita que o card pisque
  // pra spinner enquanto o "Carregar mais" busca a próxima página.
  List<Entry> _cachedEntries = const [];

  void _loadMore() {
    final current = ref.read(_editListLimitProvider);
    final next = (current + _step).clamp(_step, _maxLimit);
    if (next != current) {
      ref.read(_editListLimitProvider.notifier).state = next;
    }
  }

  int _remaining(int limit) {
    final remaining = _maxLimit - limit;
    return remaining < _step ? remaining : _step;
  }

  @override
  Widget build(BuildContext context) {
    final limit = ref.watch(_editListLimitProvider);
    final lastAsync = ref.watch(lastEntriesProvider(limit));
    final monthAsync = ref.watch(monthDataProvider(null));

    final fresh = lastAsync.value?.entries;
    if (fresh != null) _cachedEntries = fresh;
    final entries = fresh ?? _cachedEntries;

    final isLoading = lastAsync.isLoading;
    final initialLoading = isLoading && _cachedEntries.isEmpty;
    final reloading = isLoading && _cachedEntries.isNotEmpty;
    final reachedSheetEnd =
        lastAsync.hasValue && !isLoading && entries.length < limit;
    final atCap = limit >= _maxLimit;
    final canLoadMore = !isLoading && !reachedSheetEnd && !atCap;

    Future<void> openEdit(Entry e) async {
      final api = ref.read(apiProvider);
      final saved = await showDialog<bool>(
        context: context,
        builder: (_) => EditDialog(
          entry: e,
          rowsForCategoriaSuggestions:
              monthAsync.value?.rows ?? const <ExpenseRow>[],
          api: api,
        ),
      );
      if (saved == true) {
        ref.invalidate(lastEntriesProvider);
        ref.invalidate(monthDataProvider);
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  'ÚLTIMOS ${entries.length} · TOQUE PARA EDITAR',
                  style: BloomTypography.kicker(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          BloomCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            borderRadius: BorderRadius.circular(22),
            child: initialLoading
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: CircularProgressIndicator(
                          color: BloomColors.violet),
                    ),
                  )
                : entries.isEmpty
                    ? Padding(
                        padding:
                            const EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Text(
                            'Sem lançamentos.',
                            style: BloomTypography.geist(
                              fontSize: 12,
                              color: BloomColors.muted,
                            ),
                          ),
                        ),
                      )
                    : Column(
                        children: [
                          for (var i = 0; i < entries.length; i++)
                            RecentEntryRow(
                              entry: entries[i],
                              showDivider: i > 0,
                              onTap: () => openEdit(entries[i]),
                              highlightMissing: true,
                            ),
                        ],
                      ),
          ),
          const SizedBox(height: 14),
          if (reloading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 6),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: BloomColors.violet,
                    strokeWidth: 2.2,
                  ),
                ),
              ),
            )
          else if (canLoadMore)
            Center(
              child: TextButton.icon(
                onPressed: _loadMore,
                icon: const Icon(Icons.expand_more, size: 18),
                label: Text('Carregar mais ${_remaining(limit)}'),
                style: TextButton.styleFrom(
                  foregroundColor: BloomColors.violet,
                ),
              ),
            )
          else if (atCap)
            Center(
              child: Text(
                'Limite de $_maxLimit lançamentos atingido.',
                style: BloomTypography.geist(
                  fontSize: 11.5,
                  color: BloomColors.muted,
                ),
              ),
            )
          else if (reachedSheetEnd && entries.length > _step)
            Center(
              child: Text(
                'Fim da lista.',
                style: BloomTypography.geist(
                  fontSize: 11.5,
                  color: BloomColors.muted,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _NovoForm extends ConsumerStatefulWidget {
  final VoidCallback onCancel;
  const _NovoForm({required this.onCancel});

  @override
  ConsumerState<_NovoForm> createState() => _NovoFormState();
}

class _NovoFormState extends ConsumerState<_NovoForm> {
  final _valorCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _categoriaCtrl = TextEditingController();

  String _origem = kOrigemCredito;
  String _rateio = 'Metade';
  // Sem default de propósito: escolher errado é pior que não escolher.
  String _banco = ''; // '' | 'Santander' | 'Revolut'
  int _parcela = 1;
  bool _acerto = false;
  bool _busy = false;
  String? _error;
  late DateTime _data;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _data = DateTime(now.year, now.month, 6);
  }

  Future<void> _pickData() async {
    final picked = await showMonthYearPicker(context, initial: _data);
    if (picked != null && mounted) {
      setState(() => _data = picked);
    }
  }

  @override
  void dispose() {
    _valorCtrl.dispose();
    _descCtrl.dispose();
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
    setState(() => _parcela = next);
  }

  String _humanError(String? code) => switch (code) {
        'missing_descricao' => 'Informe o estabelecimento.',
        'missing_valor' => 'Informe o valor.',
        'invalid_valor' => 'Valor inválido.',
        'missing_origem' => 'Selecione a forma.',
        'invalid_origem' => 'Forma inválida.',
        'invalid_rateio' => 'Divisão inválida.',
        'invalid_banco' => 'Banco inválido.',
        'invalid_parcela' => 'Parcela inválida.',
        'invalid_acerto' => 'Acerto inválido.',
        'lock_timeout' => 'Backend ocupado. Tente de novo.',
        'unauthorized' => 'Sessão expirada. Faça login.',
        _ => code ?? 'Erro desconhecido.',
      };

  Future<void> _save() async {
    final valor = _readValor();
    final desc = _descCtrl.text.trim();
    if (desc.isEmpty) {
      setState(() => _error = 'Informe o estabelecimento.');
      return;
    }
    if (valor <= 0) {
      setState(() => _error = 'Informe um valor maior que zero.');
      return;
    }
    final isCartao = _origem == kOrigemCredito;
    if (isCartao && _banco.isEmpty) {
      setState(() => _error = 'Selecione o banco.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final api = ref.read(apiProvider);
      final fields = AddEntryFields(
        descricao: desc,
        valor: valor,
        origem: _origem,
        data: formatBrDate(_data),
        categoria: _categoriaCtrl.text.trim(),
        rateio: _rateio,
        banco: isCartao ? _banco : '',
        parcela: isCartao && _parcela > 1 ? '1/$_parcela' : '',
        acerto: !isCartao && _acerto ? 'Sim' : '',
      );
      final r = await api.addEntry(fields);
      if (!mounted) return;
      if (r.ok) {
        ref.invalidate(lastEntriesProvider);
        ref.invalidate(monthDataProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Lançamento criado.'),
            backgroundColor: BloomColors.good,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
        widget.onCancel();
      } else {
        setState(() => _error = _humanError(r.error));
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Erro: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCartao = _origem == kOrigemCredito;
    final monthAsync = ref.watch(monthDataProvider(null));
    final categorias = <String>{
      for (final r in monthAsync.value?.rows ?? const <ExpenseRow>[])
        if (r.categoria.isNotEmpty) r.categoria,
    }.toList()
      ..sort();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [BloomColors.violet, BloomColors.sky],
              ),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: BloomColors.violet.withValues(alpha: 0.25),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'VALOR',
                  style: BloomTypography.geist(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.85),
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      'R\$',
                      style: BloomTypography.geist(
                        fontSize: 18,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: TextField(
                        controller: _valorCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        style: BloomTypography.display(
                          fontSize: 38,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          height: 1,
                          letterSpacing: -1,
                        ),
                        cursorColor: Colors.white,
                        decoration: InputDecoration(
                          hintText: '0,00',
                          hintStyle: BloomTypography.display(
                            fontSize: 38,
                            fontWeight: FontWeight.w700,
                            color: Colors.white.withValues(alpha: 0.45),
                            height: 1,
                            letterSpacing: -1,
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          filled: false,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _FieldLabel(label: 'MÊS FATURA'),
          const SizedBox(height: 6),
          _MonthYearTap(
            value: monthYearShort(formatBrDate(_data)),
            onTap: _busy ? null : _pickData,
          ),
          const SizedBox(height: 14),
          _FieldLabel(label: 'ESTABELECIMENTO'),
          const SizedBox(height: 6),
          TextField(
            controller: _descCtrl,
            decoration: const InputDecoration(
              hintText: 'Ex: Mercado Extra',
              isDense: true,
            ),
            autocorrect: false,
          ),
          const SizedBox(height: 14),
          _FieldLabel(label: 'CATEGORIA'),
          const SizedBox(height: 6),
          _CategoriaAutocomplete(
            controller: _categoriaCtrl,
            options: categorias,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _FieldLabel(label: 'FORMA'),
                    const SizedBox(height: 6),
                    _Segmented(
                      options: const [kOrigemCredito, kOrigemDebito],
                      selected: isCartao ? kOrigemCredito : kOrigemDebito,
                      onChange: (v) => setState(() {
                        _origem = v == kOrigemDebito ? kOrigemDebito : kOrigemCredito;
                      }),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _FieldLabel(label: 'DIVISÃO'),
                    const SizedBox(height: 6),
                    _Segmented(
                      options: const ['Metade', 'Julio', 'Dani', 'Alzira'],
                      selected: _rateio,
                      onChange: (v) => setState(() => _rateio = v),
                      compact: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (isCartao) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _FieldLabel(label: 'PARCELA'),
                      const SizedBox(height: 6),
                      _ParcelaStepper(
                        parcela: _parcela,
                        onMinus: () => _adjustParcela(-1),
                        onPlus: () => _adjustParcela(1),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _FieldLabel(label: 'BANCO'),
                      const SizedBox(height: 6),
                      _Segmented(
                        options: const ['Santander', 'Revolut'],
                        selected: _banco,
                        onChange: (v) => setState(() => _banco = v),
                        compact: true,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ] else ...[
            const SizedBox(height: 14),
            InkWell(
              onTap: () => setState(() => _acerto = !_acerto),
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Switch.adaptive(
                      value: _acerto,
                      onChanged: (v) => setState(() => _acerto = v),
                      activeThumbColor: BloomColors.violet,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Marcar para o Acerto Final',
                        style: BloomTypography.geist(
                          fontSize: 12.5,
                          color: BloomColors.inkSoft,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: BloomColors.bad.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline,
                      size: 18, color: BloomColors.bad),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _error!,
                      style: BloomTypography.geist(
                        fontSize: 13,
                        color: BloomColors.bad,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 18),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _busy ? null : _save,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                height: 50,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _busy ? BloomColors.muted : BloomColors.ink,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        'Salvar lançamento',
                        style: BloomTypography.display(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: -0.2,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoriaAutocomplete extends StatelessWidget {
  final TextEditingController controller;
  final List<String> options;
  const _CategoriaAutocomplete({
    required this.controller,
    required this.options,
  });

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
          decoration: const InputDecoration(
            hintText: 'Ex: Alimentação',
            isDense: true,
          ),
          autocorrect: false,
        );
      },
    );
  }
}

class _ParcelaStepper extends StatelessWidget {
  final int parcela;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  const _ParcelaStepper({
    required this.parcela,
    required this.onMinus,
    required this.onPlus,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: BloomColors.card,
        border: Border.all(color: BloomColors.border, width: 1),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
      child: Row(
        children: [
          IconButton(
            onPressed: onMinus,
            icon: const Icon(Icons.remove, size: 18),
            visualDensity: VisualDensity.compact,
            color: BloomColors.inkSoft,
          ),
          Expanded(
            child: Text(
              '${parcela}x',
              textAlign: TextAlign.center,
              style: BloomTypography.geist(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: BloomColors.ink,
              ),
            ),
          ),
          IconButton(
            onPressed: onPlus,
            icon: const Icon(Icons.add, size: 18),
            visualDensity: VisualDensity.compact,
            color: BloomColors.inkSoft,
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String label;
  const _FieldLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(label, style: BloomTypography.kicker());
  }
}

class _Segmented extends StatelessWidget {
  final List<String> options;
  final String selected;
  final ValueChanged<String> onChange;
  final bool compact;

  const _Segmented({
    required this.options,
    required this.selected,
    required this.onChange,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: BloomColors.card,
        border: Border.all(color: BloomColors.border, width: 1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          for (final o in options)
            Expanded(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => onChange(o),
                  borderRadius: BorderRadius.circular(9),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected == o
                          ? BloomColors.ink
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text(
                      _shortLabel(o),
                      style: BloomTypography.geist(
                        fontSize: compact ? 11 : 12,
                        color: selected == o
                            ? Colors.white
                            : BloomColors.inkSoft,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _shortLabel(String o) => switch (o) {
        'Metade' => '½',
        'Julio' => 'Júlio',
        _ => o,
      };
}

class _MonthYearTap extends StatelessWidget {
  final String value;
  final VoidCallback? onTap;

  const _MonthYearTap({required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: BloomColors.card,
            border: Border.all(color: BloomColors.border, width: 1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  value,
                  style: BloomTypography.geist(
                    fontSize: 13,
                    color: BloomColors.ink,
                  ),
                ),
              ),
              const Icon(Icons.calendar_today_outlined,
                  size: 18, color: BloomColors.inkSoft),
            ],
          ),
        ),
      ),
    );
  }
}
