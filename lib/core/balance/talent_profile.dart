import '../numbers/stable_math.dart';

class TalentCurve {
  const TalentCurve({
    this.cap = 10,
    this.tau = 3,
    required this.maximum,
    this.baseCost = 3,
    this.costGrowth = 1.6,
  });
  final int cap;
  final double tau, maximum, baseCost, costGrowth;
  void validate({required double limit}) {
    if (cap < 1 ||
        cap > 100 ||
        !tau.isFinite ||
        tau <= 0 ||
        !maximum.isFinite ||
        maximum <= 0 ||
        maximum > limit ||
        !baseCost.isFinite ||
        baseCost <= 0 ||
        !costGrowth.isFinite ||
        costGrowth < 1) {
      throw ArgumentError('Invalid talent curve');
    }
  }

  double value(int rank) {
    if (rank < 0 || rank > cap) throw ArgumentError.value(rank, 'rank');
    if (rank == 0) return 0;
    if (rank == cap) return maximum;
    return maximum *
        StableMath.expm1(-rank / tau) /
        StableMath.expm1(-cap / tau);
  }

  Map<String, Object> toJson() => {
    'cap': cap,
    'tau': tau,
    'maximum': maximum,
    'baseCost': baseCost,
    'costGrowth': costGrowth,
  };
}

class TalentProfile {
  const TalentProfile({
    this.id = 'phase03_candidate_v1',
    this.bossDamage = const TalentCurve(maximum: .5),
    this.firstClearGold = const TalentCurve(maximum: .5),
    this.stageHeal = const TalentCurve(maximum: .2),
    this.critProtection = const TalentCurve(maximum: .6),
    this.shorterTravel = const TalentCurve(maximum: .25),
    this.stageGold = const TalentCurve(maximum: .5),
    this.firstBooks = 3,
    this.repeatBooks = 1,
    this.repeatLimit = 2,
    this.milestoneBooks = 5,
    this.stageGoldRepeatLimit = 2,
  });
  static const candidate = TalentProfile();
  final String id;
  final TalentCurve bossDamage,
      firstClearGold,
      stageHeal,
      critProtection,
      shorterTravel,
      stageGold;
  final int firstBooks,
      repeatBooks,
      repeatLimit,
      milestoneBooks,
      stageGoldRepeatLimit;
  Map<String, TalentCurve> get curves => {
    'boss_damage': bossDamage,
    'first_clear_gold': firstClearGold,
    'stage_heal': stageHeal,
    'crit_protection': critProtection,
    'shorter_travel': shorterTravel,
    'stage_gold': stageGold,
  };
  void validate() {
    if (id.isEmpty ||
        firstBooks < 0 ||
        repeatBooks < 0 ||
        milestoneBooks < 0 ||
        repeatLimit < 0 ||
        repeatLimit > 10 ||
        stageGoldRepeatLimit < 0 ||
        stageGoldRepeatLimit > 10) {
      throw ArgumentError('Invalid talent/reward profile');
    }
    for (final entry in curves.entries) {
      entry.value.validate(
        limit: switch (entry.key) {
          'stage_heal' => .3,
          'crit_protection' => .8,
          'shorter_travel' => .35,
          _ => .75,
        },
      );
    }
  }

  Map<String, Object> toJson() => {
    'id': id,
    'curves': {for (final e in curves.entries) e.key: e.value.toJson()},
    'firstBooks': firstBooks,
    'repeatBooks': repeatBooks,
    'repeatLimit': repeatLimit,
    'milestoneBooks': milestoneBooks,
    'stageGoldRepeatLimit': stageGoldRepeatLimit,
  };
}
