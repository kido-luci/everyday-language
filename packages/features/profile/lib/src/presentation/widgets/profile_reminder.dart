part of 'profile_widgets.dart';

class _ReminderCard extends StatelessWidget {
  const _ReminderCard();

  @override
  Widget build(BuildContext context) {
    return _SettingsCard(
      title: context.l10n.profileSectionReminder,
      child: BlocConsumer<ReminderCubit, ReminderState>(
        // Only the transition into a refusal is worth a message; a rebuild
        // while the flag is still set would repeat it.
        listenWhen: (previous, current) =>
            current.permissionBlocked && !previous.permissionBlocked,
        listener: (context, state) {
          final cubit = context.read<ReminderCubit>();
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text(context.l10n.profileReminderPermissionDenied),
                action: SnackBarAction(
                  label: context.l10n.profileReminderOpenSettings,
                  onPressed: cubit.openSystemSettings,
                ),
              ),
            );
          cubit.acknowledgePermissionNotice();
        },
        builder: (context, state) {
          final cubit = context.read<ReminderCubit>();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                value: state.enabled,
                onChanged: (on) => cubit.toggle(on: on),
                secondary: const FaIcon(FontAwesomeIcons.bell),
                title: Text(context.l10n.profileReminderSwitchLabel),
                subtitle: Text(context.l10n.profileReminderSwitchHint),
              ),
              const _SettingsDivider(),
              _ReminderTimeTile(state: state),
            ],
          );
        },
      ),
    );
  }
}

/// The time the reminder fires. Editable whether or not the reminder is on —
/// picking a time first and switching it on second is the more natural order,
/// and a disabled row would forbid it.
class _ReminderTimeTile extends StatelessWidget {
  const _ReminderTimeTile({required this.state});

  final ReminderState state;

  @override
  Widget build(BuildContext context) {
    final time = TimeOfDay(hour: state.hour, minute: state.minute);
    return ListTile(
      leading: const FaIcon(FontAwesomeIcons.clock),
      title: Text(context.l10n.profileReminderTimeLabel),
      trailing: Text(
        time.format(context),
        style: context.textTheme.titleMedium?.copyWith(
          color: context.colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
      onTap: () => _pick(context, time),
    );
  }

  Future<void> _pick(BuildContext context, TimeOfDay current) async {
    final cubit = context.read<ReminderCubit>();
    final chosen = await showTimePicker(context: context, initialTime: current);
    if (chosen == null) return;
    await cubit.changeTime(
      chosen.hour * Duration.minutesPerHour + chosen.minute,
    );
  }
}
