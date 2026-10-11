class StatisticsState {
  StatisticsState(Map<String, String> values)
    : values = Map.unmodifiable(values);
  final Map<String, String> values;
}
