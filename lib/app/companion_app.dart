import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'di/dependency_scope.dart';
import 'app_runtime.dart';
import 'session/session_cubit.dart';
import '../presentation/companion/cubit/overlay_cubit.dart';
import '../l10n/app_localizations.dart';
import '../presentation/companion/widgets/companion_overlay.dart';

class CompanionApp extends StatelessWidget {
  const CompanionApp({super.key, required this.runtime});
  final AppRuntime runtime;
  @override
  Widget build(BuildContext context) =>
      DependencyScope(runtime: runtime, child: const _CompanionProviders());
}

class _CompanionProviders extends StatelessWidget {
  const _CompanionProviders();
  @override
  Widget build(BuildContext context) {
    final dependencies = context.read<GetIt>();
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: dependencies<SessionCubit>()),
        BlocProvider.value(value: dependencies<OverlayCubit>()),
      ],
      child: MaterialApp(
        title: 'Idle Companion',
        debugShowCheckedModeBanner: false,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: ThemeData(
          brightness: Brightness.dark,
          colorSchemeSeed: const Color(0xff8dd7bf),
          useMaterial3: true,
          scaffoldBackgroundColor: Colors.transparent,
          visualDensity: VisualDensity.compact,
        ),
        home: const CompanionOverlay(),
      ),
    );
  }
}
