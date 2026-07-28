import 'dart:async';
import 'dart:developer' as developer;

import 'package:analytics/analytics.dart';
import 'package:app_platform/app_platform.dart';
import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_contracts/shared_contracts.dart';
import 'package:theme/theme.dart';

import '../core/extensions/build_context_extensions.dart';
import 'di/injection.dart';
import 'feature_module.dart';
import 'features.dart';
import 'router.dart';

class App extends StatefulWidget {
  const App({
    super.key,
    this.themeBloc,
    this.features,
    this.navigatorObservers,
    this.videoPlayerService,
  });

  final ThemeBloc? themeBloc;

  /// Optional feature overrides — primarily for testing. Defaults to
  /// [enabledFeatures] from `features.dart`.
  final List<FeatureModule>? features;
  final List<NavigatorObserver>? navigatorObservers;
  final VideoPlayerService? videoPlayerService;

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  late final ThemeBloc _themeBloc;
  Session? _session;
  late final GoRouter _router;
  late final DeepLinkState _deepLink;
  late final List<FeatureSyncController> _syncControllers;
  late final VideoPlayerService _videoPlayerService;

  @override
  void initState() {
    super.initState();
    _themeBloc = widget.themeBloc ?? getIt<ThemeBloc>();
    final features = widget.features ?? enabledFeatures;
    final result = buildRouterWithDeepLink(
      _session,
      featureRoutes: [
        for (final f in features) ...f.routes,
      ],
      observers: widget.navigatorObservers ?? [getIt<AnalyticsRouteObserver>()],
    );
    _router = result.router;
    _deepLink = result.deepLink;
    _syncControllers = features
        .map((f) => f.syncController)
        .whereType<FeatureSyncController>()
        .toList(growable: false);
    _videoPlayerService =
        widget.videoPlayerService ?? getIt<VideoPlayerService>();
    final session = _session;
    if (session != null) {
      session.addListener(_onSessionChanged);
    } else {
      // No auth pillar: nothing gates sync, so run it for the whole app.
      _setSyncActive(active: true);
    }
  }

  void _onSessionChanged() {
    // Sync runs only for a settled, signed-in user — not while signing out or
    // still restoring (both leave no active user).
    final session = _session!;
    _setSyncActive(
      active: session.currentUser != null && !session.isSigningOut,
    );
  }

  void _setSyncActive({required bool active}) {
    for (final c in _syncControllers) {
      unawaited(
        (active ? c.start() : c.stop()).catchError(
          (Object error, StackTrace stackTrace) {
            developer.log(
              'Feature sync lifecycle failed',
              name: 'App',
              error: error,
              stackTrace: stackTrace,
            );
          },
        ),
      );
    }
  }

  @override
  void dispose() {
    _session?.removeListener(_onSessionChanged);
    for (final c in _syncControllers) {
      unawaited(
        c.stop().catchError((Object error, StackTrace stackTrace) {
          developer.log(
            'Feature sync stop failed during dispose',
            name: 'App',
            error: error,
            stackTrace: stackTrace,
          );
        }),
      );
    }
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget app = RepositoryProvider<VideoPlayerService>.value(
      value: _videoPlayerService,
      child: MultiBlocProvider(
        providers: [
          BlocProvider.value(value: _themeBloc),
        ],
        child: BlocBuilder<ThemeBloc, ThemeState>(
          builder: (context, themeState) => MaterialApp.router(
            debugShowCheckedModeBanner: false,
            onGenerateTitle: (context) => context.l10n.appTitle,
            theme: AppTheme.light(scheme: themeState.scheme),
            darkTheme: AppTheme.dark(scheme: themeState.scheme),
            themeMode: themeState.mode,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: _router,
          ),
        ),
      ),
    );
    return DeepLinkScope(deepLink: _deepLink, child: app);
  }
}
