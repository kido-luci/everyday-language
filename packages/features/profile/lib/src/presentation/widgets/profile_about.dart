part of 'profile_widgets.dart';

class _AboutCard extends StatelessWidget {
  const _AboutCard();

  @override
  Widget build(BuildContext context) {
    return _SettingsCard(
      title: context.l10n.profileSectionAbout,
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _AppInfoTile(),
          _SettingsDivider(),
          _LicensesTile(),
        ],
      ),
    );
  }
}

/// Opens Flutter's aggregated license page.
///
/// Not a nicety: the MIT and BSD dependencies this app ships require their
/// copyright notices to be reproduced in distributions, and an app binary has
/// nowhere else to put them. `LicenseRegistry` collects them at build time, so
/// this stays correct as dependencies come and go.
class _LicensesTile extends StatelessWidget {
  const _LicensesTile();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProfileBloc, ProfileState>(
      builder: (context, state) {
        final info = state.packageInfo;
        return ListTile(
          leading: const FaIcon(FontAwesomeIcons.scaleBalanced),
          title: Text(context.l10n.profileLicenses),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => showLicensePage(
            context: context,
            applicationName: info?.appName,
            applicationVersion: info?.version,
          ),
        );
      },
    );
  }
}

class _AppInfoTile extends StatelessWidget {
  const _AppInfoTile();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProfileBloc, ProfileState>(
      builder: (context, state) {
        final info = state.packageInfo;
        return ListTile(
          leading: const FaIcon(FontAwesomeIcons.circleInfo),
          title: Text(info?.appName ?? '—'),
          subtitle: info == null
              ? Text(context.l10n.commonLoading)
              : Text(
                  context.l10n.profileAppVersionBuild(
                    info.version,
                    info.buildNumber,
                  ),
                ),
        );
      },
    );
  }
}
