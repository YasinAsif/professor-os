class ProctorAttemptSummary {
  final int active;
  final int flagged;

  const ProctorAttemptSummary({required this.active, required this.flagged});
}

List<Map<String, dynamic>> normalizeProctorAttempts(List<dynamic> raw) => raw
    .whereType<Map>()
    .map((item) => Map<String, dynamic>.from(item))
    .toList(growable: false);

ProctorAttemptSummary summarizeProctorAttempts(
    List<Map<String, dynamic>> attempts) {
  return ProctorAttemptSummary(
    active: attempts.where((attempt) => attempt['submitted_at'] == null).length,
    flagged: attempts.where((attempt) => attempt['is_flagged'] == true).length,
  );
}
