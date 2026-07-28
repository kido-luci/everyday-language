// Unit tests for the splash/auth redirect state machine that drives the app's
// cold-start flow. The logic lives in `resolveSplashRedirect`
// (lib/app/router.dart), extracted from GoRouter's `redirect` callback so the
// three phases can be exercised without assembling a router + widget tree.
//
// The phases:
//   1. Before splash completes — capture the requested URI, force /splash.
//   2. Splash done, unauthenticated — force /login (allowing login/register).
//   3. Splash done, authenticated — replay a captured deep link, otherwise
//      bounce off splash/login/register to home and allow protected routes.

import 'package:everyday_language/app/router.dart';
import 'package:flutter_test/flutter_test.dart';

const splash = '/splash';
const home = '/';

/// Builds a fresh deep-link gate for one navigation.
DeepLinkState gate({bool splashCompleted = false, String? pending}) {
  return DeepLinkState()
    ..splashCompleted = splashCompleted
    ..pendingRedirect = pending;
}

void main() {
  group('no auth pillar — status null, splash is the only gate', () {
    String? resolveNoAuth({
      required String location,
      required DeepLinkState deepLink,
      String? requestedUri,
    }) {
      return resolveSplashRedirect(
        status: null,
        location: location,
        requestedUri: requestedUri ?? location,
        deepLink: deepLink,
        splashLocation: splash,
        homeLocation: home,
      );
    }

    test('still forces splash before it completes, capturing the target', () {
      final deepLink = gate();
      expect(resolveNoAuth(location: home, deepLink: deepLink), splash);
      expect(deepLink.pendingRedirect, home);
    });

    test('bounces off splash to home once completed', () {
      final deepLink = gate(splashCompleted: true);
      expect(resolveNoAuth(location: splash, deepLink: deepLink), home);
    });

    test('replays a captured deep link', () {
      final deepLink = gate(splashCompleted: true, pending: '/bookmarks');
      expect(resolveNoAuth(location: splash, deepLink: deepLink), '/bookmarks');
      expect(deepLink.pendingRedirect, isNull);
    });

    test('allows any route without an auth gate', () {
      final deepLink = gate(splashCompleted: true);
      expect(resolveNoAuth(location: '/bookmarks', deepLink: deepLink), isNull);
    });
  });
}
