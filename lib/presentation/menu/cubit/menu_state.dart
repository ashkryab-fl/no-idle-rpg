import '../../companion/cubit/overlay_state.dart';

class MenuState {
  MenuState(this.idleSeconds, List<OverlayPanel> destinations)
    : destinations = List.unmodifiable(destinations);
  final double idleSeconds;
  final List<OverlayPanel> destinations;
}
