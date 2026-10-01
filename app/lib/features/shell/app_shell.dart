// Spec: docs/specs/pages/{inicio,compart,lancamento,historico,acerto}.md
// Shell do app — gradient background + IndexedStack p/ preservar estado entre as 5 abas.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../state/data_providers.dart';
import '../../state/nav_provider.dart';
import '../../widgets/bloom/bloom_bottom_nav.dart';
import '../../widgets/bloom/bloom_screen.dart';
import '../acerto/acerto_page.dart';
import '../compart/compart_page.dart';
import '../historico/historico_page.dart';
import '../inicio/inicio_page.dart';
import '../lancamento/lancamento_page.dart';
import '../../core/types.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  static const _pages = <Widget>[
    InicioPage(),
    CompartPage(),
    LancamentoPage(),
    HistoricoPage(),
    AcertoPage(),
  ];

  @override
  void initState() {
    super.initState();

    // Hidrata currentMonth automaticamente quando a primeira monthData chegar.
    ref.listenManual<AsyncValue<MonthDataResponse>>(
      monthDataProvider(null),
      (_, next) {
        next.whenData((d) {
          final cur = ref.read(currentMonthProvider);
          if (cur == null && d.month != null) {
            ref.read(currentMonthProvider.notifier).state = d.month;
          }
        });
      },
      fireImmediately: true,
    );

    // Hidrata allMonths quando historicalSummary chegar.
    ref.listenManual<AsyncValue<HistoricalSummaryResponse>>(
      historicalSummaryProvider,
      (_, next) {
        next.whenData((d) {
          if (d.months.isNotEmpty) {
            ref.read(allMonthsProvider.notifier).state = d.months;
          }
        });
      },
      fireImmediately: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tab = ref.watch(activeTabProvider);
    final index = BloomTab.values.indexOf(tab);
    return BloomScreen(
      bottomNav: BloomBottomNav(
        active: tab,
        onChange: (t) {
          // Entrar na Categoria pela barra inferior é navegação sem contexto:
          // nenhum tile de origem vem marcado. Quem marca é a Início.
          if (t == BloomTab.compart) {
            ref.read(compartOrigemFilterProvider.notifier).state = null;
          }
          ref.read(activeTabProvider.notifier).state = t;
        },
      ),
      child: IndexedStack(index: index, children: _pages),
    );
  }
}
