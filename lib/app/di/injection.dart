import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';
import '../app_runtime.dart';
import 'injection.config.dart';

/// Bootstrap supplies the loaded runtime; Injectable wires the dependency graph.
@InjectableInit(
  preferRelativeImports: true,
  ignoreUnregisteredTypes: [AppRuntime],
  throwOnMissingDependencies: true,
)
GetIt configureDependencies({AppRuntime? runtime}) {
  final dependencies = GetIt.asNewInstance();
  if (runtime != null) dependencies.registerSingleton<AppRuntime>(runtime);
  return dependencies.init();
}
