import 'dart:async';
import 'dart:developer' as developer;

import 'package:analytics/analytics.dart';
import 'package:app_platform/app_platform.dart';
import 'package:app_ui/app_ui.dart';
import 'package:feature_vocabulary/feature_vocabulary.dart';
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
    this.sharedTextService,
  });

  final ThemeBloc? themeBloc;

  /// Optional feature overrides — primarily for testing. Defaults to
  /// [enabledFeatures] from `features.dart`.
  final List<FeatureModule>? features;
  final List<NavigatorObserver>? navigatorObservers;
  final VideoPlayerService? videoPlayerService;

  /// Overridable so a test can feed a share in without a platform channel.
  final SharedTextService? sharedTextService;

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
  late final SharedTextService _sharedText;
  StreamSubscription<String>? _sharedTextSubscription;

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
    _sharedText = widget.sharedTextService ?? getIt<SharedTextService>();
    unawaited(_watchSharedText());
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

  /// Opens the capture form for anything shared into the app.
  ///
  /// Both arrival routes are handled: a share that launched the app is waiting
  /// in [SharedTextService.initialText], and later ones come down the stream.
  /// Wiring only the stream is the classic version of this bug — it works
  /// perfectly while the app is already open and does nothing from a cold
  /// start, which is the common case for a share.
  Future<void> _watchSharedText() async {
    try {
      final initial = await _sharedText.initialText();
      if (initial != null) _openCapture(initial);
      _sharedTextSubscription = _sharedText.textStream().listen(_openCapture);
    } on Object catch (error, stackTrace) {
      developer.log(
        'Could not listen for shared text',
        name: 'App',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  void _openCapture(String raw) {
    final capture = SharedCapture.parse(raw);
    if (capture.isEmpty) return;

    final target = AddWordRoute(
      word: capture.word,
      sentence: capture.sentence,
    ).location;

    if (_deepLink.splashCompleted) {
      _router.push<void>(target);
    } else {
      // Cold start: the router is still holding everything at splash. Handing
      // the target to the same gate a deep link uses replays it once splash
      // finishes, rather than racing it with a push that would be swallowed.
      _deepLink.pendingRedirect = target;
    }

    // Tell the platform it has been taken, so re-opening the app later does
    // not offer the same word again.
    unawaited(_sharedText.markHandled());
  }

  @override
  void dispose() {
    unawaited(_sharedTextSubscription?.cancel());
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
