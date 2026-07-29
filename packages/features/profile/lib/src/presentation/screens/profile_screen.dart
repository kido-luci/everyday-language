import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../locator.dart';
import '../bloc/profile_bloc.dart';
import '../bloc/reminder/reminder_cubit.dart';
import '../widgets/profile_widgets.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<ProfileBloc>(
          create: (_) => getIt<ProfileBloc>()..add(const ProfileLoaded()),
        ),
        BlocProvider<ReminderCubit>(
          create: (_) => getIt<ReminderCubit>()..load(),
        ),
      ],
      child: const ProfileBody(),
    );
  }
}
