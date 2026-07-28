part of 'profile_widgets.dart';

class _AboutCard extends StatelessWidget {
  const _AboutCard();

  @override
  Widget build(BuildContext context) {
    return _SettingsCard(
      title: context.l10n.profileSectionAbout,
      child: const _AppInfoTile(),
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
