import 'dart:async';

import 'package:flutter/material.dart' hide Text;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/l10n/app_text.dart';
import '../core/constants/app_config.dart';
import '../core/l10n/l10n.dart';
import '../core/network/network_status.dart';
import '../core/notifications/push_service.dart';
import '../core/theme/app_theme.dart';
import '../features/auth/presentation/providers/auth_providers.dart';
import '../features/notifications/presentation/providers/notifications_providers.dart';
import '../shared/widgets/common.dart';
import 'di.dart';
import 'currency_provider.dart';
import 'locale_provider.dart';
import 'router.dart';
import 'session_coordinator.dart';

class B2bApp extends ConsumerStatefulWidget {
  const B2bApp({super.key});

  @override
  ConsumerState<B2bApp> createState() => _B2bAppState();
}

class _B2bAppState extends ConsumerState<B2bApp> with WidgetsBindingObserver {
  StreamSubscription<PushPayload>? _pushSub;
  StreamSubscription<String>? _tokenSub;
  DateTime _lastSync = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final push = ref.read(pushServiceProvider);
    _pushSub = push.foregroundMessages.listen(_onPush);
    _tokenSub = push.tokenRefreshes.listen((_) {
      if (ref.read(authControllerProvider).isAuthenticated) {
        unawaited(ref.read(sessionCoordinatorProvider).registerDevice());
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pushSub?.cancel();
    _tokenSub?.cancel();
    super.dispose();
  }

  void _onPush(PushPayload message) {
    ref.invalidate(notificationsProvider);
    final text = <String>[
      if (message.title != null && message.title!.isNotEmpty) message.title!,
      if (message.body != null && message.body!.isNotEmpty) message.body!,
    ].join('\n');
    if (text.isEmpty) return;
    rootMessengerKey.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text), duration: const Duration(seconds: 5)));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // не чаще раза в минуту
      if (DateTime.now().difference(_lastSync).inSeconds >= 60) {
        _lastSync = DateTime.now();
        unawaited(ref.read(sessionCoordinatorProvider).syncAll());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final locale = ref.watch(localeProvider);
    ref.watch(currencyProvider);

    ref.listen<AuthState>(authControllerProvider, (previous, next) {
      if (next.sessionExpired) {
        ref.read(sessionCoordinatorProvider).onLogout();
        ref.read(authControllerProvider.notifier).acknowledgeExpired();
        rootMessengerKey.currentState
          ?..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(content: Text('Сессия истекла. Войдите снова.'), duration: Duration(seconds: 4)),
          );
      }
    });

    ref.listen<bool>(networkStatusProvider, (previous, next) {
      if (previous == false && next) {
        _lastSync = DateTime.now();
        unawaited(ref.read(sessionCoordinatorProvider).syncAll());
      }
    });

    return MaterialApp.router(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: router,
      scaffoldMessengerKey: rootMessengerKey,
      locale: locale,
      supportedLocales: L10n.supportedLocales,
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        final media = MediaQuery.of(context);
        final scale = media.textScaler.clamp(minScaleFactor: 0.9, maxScaleFactor: 1.2);
        return MediaQuery(
          data: media.copyWith(textScaler: scale),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
