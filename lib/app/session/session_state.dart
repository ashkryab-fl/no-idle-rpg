class SessionState {
  const SessionState({
    this.revision = 0,
    this.error,
    this.notice,
    this.idleSeconds = 0,
    this.settingsRequest = 0,
  });
  final int revision;
  final String? error, notice;
  final double idleSeconds;
  // Monotonic request lets overlay navigation react without coupling session to UI.
  final int settingsRequest;
}
