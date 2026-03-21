/// Holds all collected sensor/context data used for risk scoring.
class RiskContext {
  final double? latitude;
  final double? longitude;
  final DateTime time;
  final double? lightLevel; // lux — null if sensor unavailable
  final int crowdScore; // 0–10 simulated

  const RiskContext({
    this.latitude,
    this.longitude,
    required this.time,
    this.lightLevel,
    required this.crowdScore,
  });
}
