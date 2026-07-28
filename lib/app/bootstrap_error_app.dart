import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

/// Minimal, dependency-free app shown when bootstrap fails before the real
/// `App` (and its theming/localization) can start.
///
/// It deliberately avoids `getIt`, `AppLocalizations`, and the custom theme —
/// any of those may be the thing that failed to initialize. Text is plain
/// English; the underlying error is surfaced only in debug builds.
class BootstrapErrorApp extends StatelessWidget {
  const BootstrapErrorApp({required this.error, super.key});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const FaIcon(FontAwesomeIcons.circleExclamation, size: 56),
                  const SizedBox(height: 16),
                  Text(
                    'Something went wrong',
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'The app could not start. Please close it and try '
                    'again.',
                    textAlign: TextAlign.center,
                  ),
                  if (kDebugMode) ...[
                    const SizedBox(height: 24),
                    Text(
                      '$error',
                      style: Theme.of(context).textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
