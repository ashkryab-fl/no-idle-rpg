import CoreGraphics
for state in [CGEventSourceStateID.combinedSessionState, .hidSystemState] {
  for event in [CGEventType.keyDown, .mouseMoved, .leftMouseDown, .scrollWheel] {
    print("\(state.rawValue) / \(event.rawValue): \(CGEventSource.secondsSinceLastEventType(state, eventType: event))")
  }
}
