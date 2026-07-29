import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../locator.dart';
import '../bloc/home_bloc.dart';
import '../widgets/home_widgets.dart';

/// The learner's dashboard: streak, today's goal, and what is waiting.
///
/// Navigation is handed in rather than performed here, the same way the
/// vocabulary screens do it, so this feature stays free of the app's routes.
class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.onReview,
    required this.onAddWord,
  });

  final Future<void> Function() onReview;
  final Future<void> Function() onAddWord;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<HomeBloc>()..add(const HomeLoadRequested()),
      child: HomeBody(onReview: onReview, onAddWord: onAddWord),
    );
  }
}
