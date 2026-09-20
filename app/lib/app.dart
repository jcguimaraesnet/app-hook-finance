// Spec: docs/specs/pages/inicio.md (entry route)
// Spec: docs/specs/state/persistence.md (auth gate)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'core/types.dart';
import 'features/debito/debito_page.dart';
import 'features/detalhe/detalhe_page.dart';
import 'features/login/login_screen.dart';
import 'features/settings/captures_history_page.dart';
import 'features/settings/settings_page.dart';
import 'features/shell/app_shell.dart';
import 'state/auth_provider.dart';
import 'state/notification_capture_provider.dart';
import 'theme/theme.dart';

class HookFinanceApp extends ConsumerStatefulWidget {
  const HookFinanceApp({super.key});

  @override
  ConsumerState<HookFinanceApp> createState() => _HookFinanceAppState();
}

class _HookFinanceAppState extends ConsumerState<HookFinanceApp> {
  late final _AuthListenable _authListenable;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _authListenable = _AuthListenable(ref);
    _router = GoRouter(
      initialLocation: '/login',
      refreshListenable: _authListenable,
      redirect: (context, state) {
        final auth = ref.read(authProvider);
        if (!auth.ready) return null;
        final atLogin = state.matchedLocation == '/login';
        if (auth.isAuthed && atLogin) return '/';
        if (!auth.isAuthed && !atLogin) return '/login';
        return null;
      },
      routes: [
        GoRoute(
          path: '/login',
          builder: (_, _) => const LoginScreen(),
        ),
        GoRoute(
          path: '/',
          builder: (_, _) => const AppShell(),
          routes: [
            GoRoute(
              path: 'detalhe',
              builder: (_, state) {
                final p = state.uri.queryParameters['person'];
                final initial =
                    p == 'dani' ? Person.dani : Person.julio;
                return DetalhePage(initialPerson: initial);
              },
            ),
            GoRoute(
              path: 'debito',
              builder: (_, state) {
                final p = state.uri.queryParameters['person'];
                final initial = p == 'dani' ? Person.dani : Person.julio;
                return DebitoPage(initialPerson: initial);
              },
            ),
            GoRoute(
              path: 'settings',
              builder: (_, _) => const SettingsPage(),
            ),
            GoRoute(
              path: 'settings/captures',
              builder: (_, _) => const CapturesHistoryPage(),
            ),
          ],
        ),
      ],
    );
    Future.microtask(() async {
      await ref.read(authProvider.notifier).hydrate();
      await ref.read(notificationCaptureProvider.notifier).hydrate();
      // Força criação do controller: ele assina o stream de notificações
      // e reage a mudanças de config. Sem read, o Provider lazy nunca roda.
      ref.read(notificationCaptureControllerProvider);
    });
  }

  @override
  void dispose() {
    _authListenable.dispose();
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'hook-finance',
      theme: buildAppTheme(),
      routerConfig: _router,
      debugShowCheckedModeBanner: false,
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}

/// Bridge entre Riverpod e go_router: dispara `notifyListeners` sempre que
/// authProvider muda. Usa `listenManual` (chamável fora de build); `ref.listen`
/// não funciona aqui porque exige contexto de build do Consumer.
class _AuthListenable extends ChangeNotifier {
  _AuthListenable(WidgetRef ref) {
    _sub = ref.listenManual<AuthState>(
      authProvider,
      (_, _) => notifyListeners(),
    );
  }

  late final ProviderSubscription<AuthState> _sub;

  @override
  void dispose() {
    _sub.close();
    super.dispose();
  }
}
