import '../hero/actor_component.dart';

class EnemyComponent extends ActorComponent {
  EnemyComponent(super.simulation, super.frameCache) : super(hero: false);
}
