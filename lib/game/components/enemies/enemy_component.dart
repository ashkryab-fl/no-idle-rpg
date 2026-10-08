import '../hero/actor_component.dart';

class EnemyComponent extends ActorComponent {
  EnemyComponent(super.simulation, super.animationSprites) : super(hero: false);
}
