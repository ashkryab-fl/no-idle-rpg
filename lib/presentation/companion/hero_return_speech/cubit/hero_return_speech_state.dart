enum HeroSpeechKind { restReturn, breakReminder }

class HeroReturnSpeechState {
  const HeroReturnSpeechState({
    this.lineIndex,
    this.kind = HeroSpeechKind.restReturn,
  });
  final int? lineIndex;
  final HeroSpeechKind kind;
}
