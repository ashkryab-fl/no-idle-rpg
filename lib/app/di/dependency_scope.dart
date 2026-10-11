import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import '../app_runtime.dart';
import 'injection.dart';

/// Each application tree owns and disposes its dependency container.
class DependencyScope extends StatelessWidget {
  const DependencyScope({super.key, this.runtime, required this.child});
  final AppRuntime? runtime;
  final Widget child;

  @override
  Widget build(BuildContext context) => RepositoryProvider<GetIt>(
    create: (_) => configureDependencies(runtime: runtime),
    dispose: (dependencies) => unawaited(dependencies.reset()),
    child: child,
  );
}
