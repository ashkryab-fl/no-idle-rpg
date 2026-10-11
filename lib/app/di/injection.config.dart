// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// InjectableConfigGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes

import 'dart:math' as _i407;

import 'package:get_it/get_it.dart' as _i174;
import 'package:injectable/injectable.dart' as _i526;

import '../../presentation/companion/cubit/overlay_cubit.dart' as _i696;
import '../../presentation/companion/hero_return_speech/cubit/hero_return_speech_cubit.dart'
    as _i61;
import '../../presentation/menu/cubit/menu_cubit.dart' as _i134;
import '../../presentation/menu/debug/cubit/debug_cubit.dart' as _i814;
import '../../presentation/menu/settings/cubit/settings_cubit.dart' as _i759;
import '../../presentation/menu/statistics/cubit/statistics_cubit.dart'
    as _i773;
import '../../presentation/menu/upgrades/equipment/cubit/equipment_cubit.dart'
    as _i1015;
import '../../presentation/menu/upgrades/talents/cubit/talents_cubit.dart'
    as _i898;
import '../../presentation/recovery/cubit/recovery_cubit.dart' as _i556;
import '../../presentation/recovery/cubit/recovery_request.dart' as _i568;
import '../app_runtime.dart' as _i813;
import '../session/session_cubit.dart' as _i796;
import '../session/session_updates_service.dart' as _i849;

extension GetItInjectableX on _i174.GetIt {
  // initializes the registration of main-scope dependencies inside of GetIt
  _i174.GetIt init({
    String? environment,
    _i526.EnvironmentFilter? environmentFilter,
  }) {
    final gh = _i526.GetItHelper(this, environment, environmentFilter);
    gh.lazySingleton<_i796.SessionCubit>(
      () => _i796.SessionCubit(gh<_i813.AppRuntime>()),
      dispose: (i) => i.close(),
    );
    gh.factoryParam<_i556.RecoveryCubit, _i568.RecoveryRequest, dynamic>(
      (request, _) => _i556.RecoveryCubit.create(request),
    );
    gh.lazySingleton<_i849.SessionUpdatesService>(
      () => _i849.SessionUpdatesService(gh<_i796.SessionCubit>()),
      dispose: (i) => i.dispose(),
    );
    gh.lazySingleton<_i696.OverlayCubit>(
      () => _i696.OverlayCubit(
        gh<_i796.SessionCubit>(),
        gh<_i849.SessionUpdatesService>(),
      )..subscribeToSession(),
      dispose: (i) => i.dispose(),
    );
    gh.factory<_i814.DebugCubit>(
      () => _i814.DebugCubit(
        gh<_i796.SessionCubit>(),
        gh<_i849.SessionUpdatesService>(),
      )..subscribeToSession(),
    );
    gh.factory<_i773.StatisticsCubit>(
      () => _i773.StatisticsCubit(
        gh<_i796.SessionCubit>(),
        gh<_i849.SessionUpdatesService>(),
      )..subscribeToSession(),
    );
    gh.factory<_i1015.EquipmentCubit>(
      () => _i1015.EquipmentCubit(
        gh<_i796.SessionCubit>(),
        gh<_i849.SessionUpdatesService>(),
      )..subscribeToSession(),
    );
    gh.factory<_i898.TalentsCubit>(
      () => _i898.TalentsCubit(
        gh<_i796.SessionCubit>(),
        gh<_i849.SessionUpdatesService>(),
      )..subscribeToSession(),
    );
    gh.factoryParam<_i61.HeroReturnSpeechCubit, int, _i407.Random?>(
      (lineCount, random) => _i61.HeroReturnSpeechCubit.create(
        gh<_i796.SessionCubit>(),
        gh<_i849.SessionUpdatesService>(),
        lineCount,
        random,
      )..subscribeToSession(),
    );
    gh.factory<_i134.MenuCubit>(
      () => _i134.MenuCubit(
        gh<_i796.SessionCubit>(),
        gh<_i696.OverlayCubit>(),
        gh<_i849.SessionUpdatesService>(),
      )..subscribeToSession(),
    );
    gh.factory<_i759.SettingsCubit>(
      () => _i759.SettingsCubit(
        gh<_i796.SessionCubit>(),
        gh<_i696.OverlayCubit>(),
        gh<_i849.SessionUpdatesService>(),
      )..subscribeToSession(),
    );
    return this;
  }
}
