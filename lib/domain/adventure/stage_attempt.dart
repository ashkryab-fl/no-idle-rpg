import '../../core/balance/talent_profile.dart';
import '../../core/numbers/amount.dart';
import '../talents/talents.dart';

/// Stored values, rather than recalculated ranks, define an in-flight attempt.
class TalentEffects {
  TalentEffects([Map<String, double> values = const {}])
    : values = Map.unmodifiable(values);
  final Map<String, double> values;
  double operator [](String id) => values[id] ?? 0;
  Map<String, double> toJson() => values;
  factory TalentEffects.fromJson(Map<String, dynamic> json) {
    final values = <String, double>{};
    for (final e in json.entries) {
      TalentCatalog.require(e.key);
      final v = (e.value as num).toDouble();
      final limit = switch (e.key) {
        'stage_heal' => .3,
        'crit_protection' => .8,
        'shorter_travel' => .35,
        'first_clear_gold' => 3,
        _ => .75,
      };
      if (!v.isFinite || v < 0 || v > limit) {
        throw const FormatException('Invalid attempt effect');
      }
      values[e.key] = v;
    }
    return TalentEffects(values);
  }
}

class EncounterPlan {
  const EncounterPlan(this.enemyId, this.distance, this.gold);
  final String enemyId;
  final double distance;
  final Amount gold;
  Map<String, Object?> toJson() => {
    'enemyId': enemyId,
    'distance': distance,
    'gold': gold.toJson(),
  };
  factory EncounterPlan.fromJson(Map<String, dynamic> json) {
    final distance = (json['distance'] as num).toDouble();
    final id = json['enemyId'] as String;
    if (!distance.isFinite || distance < 90 || distance > 160 || id.isEmpty) {
      throw const FormatException('Invalid encounter plan');
    }
    return EncounterPlan(id, distance, Amount.fromJson(json['gold']));
  }
}

class StageAttempt {
  StageAttempt({
    required this.id,
    required this.stage,
    required this.profileId,
    required Map<String, int> ranks,
    required this.effects,
    required List<EncounterPlan> encounters,
  }) : ranks = Map.unmodifiable(ranks),
       encounters = List.unmodifiable(encounters) {
    if (id < 1 || stage < 1 || encounters.length != 5) {
      throw ArgumentError('Invalid attempt');
    }
    for (final encounter in encounters) {
      if (encounter.enemyId.isEmpty ||
          !encounter.distance.isFinite ||
          encounter.distance < 90 ||
          encounter.distance > 160) {
        throw ArgumentError('Invalid encounter plan');
      }
    }
    final pairs = <TalentPair>{};
    for (final e in ranks.entries) {
      final definition = TalentCatalog.require(e.key);
      if (e.value < 1 || e.value > 10 || !pairs.add(definition.pair)) {
        throw ArgumentError('Invalid attempt selection');
      }
    }
    if (effects.values.length != ranks.length ||
        effects.values.keys.any((id) => !ranks.containsKey(id))) {
      throw ArgumentError('Effect without selection');
    }
  }
  final int id, stage;
  final String profileId;
  final Map<String, int> ranks;
  final TalentEffects effects;
  final List<EncounterPlan> encounters;
  Amount get nominalGold =>
      encounters.fold(Amount.zero, (sum, wave) => sum + wave.gold);
  factory StageAttempt.begin(
    TalentProgress progress,
    int stage,
    List<EncounterPlan> encounters, {
    TalentProfile profile = TalentProfile.candidate,
  }) {
    profile.validate();
    if (progress.nextAttemptId >= 9007199254740991) {
      throw StateError('Attempt counter exhausted');
    }
    final ranks = <String, int>{}, effects = <String, double>{};
    for (final entry in progress.selectedForNextAttempt.entries) {
      final id = entry.value;
      final definition = TalentCatalog.require(id);
      if (definition.pair != entry.key) {
        throw StateError('Invalid selected pair');
      }
      final rank = progress.ownedRanks[id] ?? 0;
      if (rank < 1 || rank > progress.rankLimit(definition, profile)) {
        throw StateError('Unavailable attempt selection');
      }
      ranks[id] = rank;
      effects[id] = profile.curves[id]!.value(rank);
    }
    final attempt = StageAttempt(
      id: progress.nextAttemptId,
      stage: stage,
      profileId: profile.id,
      ranks: ranks,
      effects: TalentEffects(effects),
      encounters: encounters,
    );
    progress.nextAttemptId++;
    return attempt;
  }
  Map<String, Object?> toJson() => {
    'id': id,
    'stage': stage,
    'profileId': profileId,
    'ranks': ranks,
    'effects': effects.toJson(),
    'encounters': encounters.map((e) => e.toJson()).toList(),
  };
  factory StageAttempt.fromJson(Map<String, dynamic> json) {
    if (json['profileId'] != TalentProfile.candidate.id) {
      throw const FormatException(
        'Unknown saved talent profile; recovery required',
      );
    }
    final result = StageAttempt(
      id: json['id'] as int,
      stage: json['stage'] as int,
      profileId: json['profileId'] as String,
      ranks: Map<String, int>.from(json['ranks'] as Map),
      effects: TalentEffects.fromJson(
        Map<String, dynamic>.from(json['effects'] as Map),
      ),
      encounters: (json['encounters'] as List)
          .map(
            (e) => EncounterPlan.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList(),
    );
    for (final e in result.ranks.entries) {
      final expected = TalentProfile.candidate.curves[e.key]!.value(e.value);
      if ((result.effects[e.key] - expected).abs() > 1e-12) {
        throw const FormatException(
          'Saved effect does not match its paid rank/profile',
        );
      }
    }
    return result;
  }
}
