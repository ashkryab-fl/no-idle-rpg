import '../../../core/animation/animation_clip.dart';
import '../../../core/animation/animation_resources.dart';
import '../../../core/animation/ids.dart';
import '../../../core/animation/sprite_frame.dart';
import '../../../core/animation/sprite_rig.dart';
import '../../../core/animation/sprite_sheet_adapter.dart';
import '../../../core/balance/game_balance.dart';
import 'poses.dart';

part 'clip_builder.dart';
part 'clips/walk.dart';
part 'clips/attack.dart';
part 'clips/idle.dart';
part 'clips/death.dart';
part 'clips/sit_down.dart';
part 'clips/seated.dart';
part 'clips/sharpen.dart';
part 'clips/stand_up.dart';
part 'clips/read.dart';
part 'clips/read_cleanup.dart';
part 'clips/phone.dart';
part 'clips/sleep.dart';
part 'clips/sleep_standing.dart';
part 'clips/feed_birds.dart';
part 'clips/coffee.dart';

/// Hero clip timelines and their shared sprite resources.
abstract final class HeroClips {
  static const read = ClipId('hero.read');
  static const readCleanup = ClipId('hero.readCleanup');
  static const phoneEnter = ClipId('hero.phoneEnter');
  static const phoneScroll = ClipId('hero.phoneScroll');
  static const phoneWake = ClipId('hero.phoneWake');
  static const sleep = ClipId('hero.sleep');
  static const sleepStanding = ClipId('hero.sleepStanding');
  static const feedBirds = ClipId('hero.feedBirds');
  static const feedBirdsStanding = ClipId('hero.feedBirdsStanding');
  static const coffeeEnter = ClipId('hero.coffeeEnter');
  static const coffee = ClipId('hero.coffee');

  static AnimationResources resources() {
    final builder = _HeroClipBuilder();
    _addHeroWalk(builder);
    _addHeroAttack(builder);
    _addHeroIdle(builder);
    _addHeroDeath(builder);
    _addHeroSitDown(builder);
    _addHeroSeated(builder);
    _addHeroSharpen(builder);
    _addHeroStandUp(builder);
    _addHeroRead(builder);
    _addHeroReadCleanup(builder);
    _addHeroPhone(builder);
    _addHeroSleep(builder);
    _addHeroSleepStanding(builder);
    _addHeroFeedBirds(builder);
    _addHeroCoffee(builder);

    return builder.build();
  }
}
