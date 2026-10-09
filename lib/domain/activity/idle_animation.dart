export 'idle_animation_definition.dart';
export 'idle_level.dart';
export 'rest_coordinator.dart';

import 'rest_coordinator.dart';

/// Compatibility name for existing callers, removed in migration stage 5.
typedef IdleBehaviorSystem = RestCoordinator;
