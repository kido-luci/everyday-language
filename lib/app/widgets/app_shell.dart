import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:localization/localization.dart';


/// Hosts the persistent adaptive navigation around the authenticated branches.
///
/// Renders an [AppAdaptiveScaffold] whose body is the [navigationShell] (the
/// indexed stack of branch navigators), so each destination keeps its own
/// navigation stack.
class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    final destinations = [
      AppDestination(
        icon: FontAwesomeIcons.house,
        selectedIcon: FontAwesomeIcons.house,
        label: l10n.navHome,
      ),
      AppDestination(
        icon: FontAwesomeIcons.user,
        selectedIcon: FontAwesomeIcons.solidUser,
        label: l10n.navProfile,
      ),
    ];

    return AppAdaptiveScaffold(
      destinations: destinations,
      selectedIndex: widget.navigationShell.currentIndex,
      onDestinationSelected: (index) {
        widget.navigationShell.goBranch(
          index,
          initialLocation: index == widget.navigationShell.currentIndex,
        );
      },
      body: widget.navigationShell,
    );
  }
}
