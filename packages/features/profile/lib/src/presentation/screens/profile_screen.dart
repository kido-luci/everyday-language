import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../locator.dart';
import '../bloc/profile_bloc.dart';
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
      ],
      child: const ProfileBody(),
    );
  }
}
