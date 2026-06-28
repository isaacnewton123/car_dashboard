/// Severity classification for OBD-II Diagnostic Trouble Codes.
enum DtcSeverity {
  /// Critical issue requiring immediate attention.
  error,

  /// Potential issue that should be investigated.
  warning,

  /// Informational — no immediate action needed.
  info,
}

/// Represents a single OBD-II Diagnostic Trouble Code (DTC).
class DtcCode {
  const DtcCode({
    required this.code,
    required this.description,
    required this.severity,
  });

  /// The standardized DTC string (e.g. "P0301").
  final String code;

  /// Human-readable description of the fault.
  final String description;

  /// Severity level for UI badge coloring.
  final DtcSeverity severity;
}
