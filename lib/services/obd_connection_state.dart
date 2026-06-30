/// Connection lifecycle states for the OBD-II Bluetooth adapter.
library;

/// Represents the current stage of the OBD-II Bluetooth connection.
enum ObdConnectionStatus {
  /// No adapter connected; using mock data fallback.
  disconnected('Disconnected'),

  /// Actively scanning for paired Bluetooth devices.
  scanning('Scanning...'),

  /// Bluetooth RFCOMM socket is being established.
  connecting('Connecting...'),

  /// ELM327 AT initialization commands are being sent.
  initializing('Initializing ELM327...'),

  /// Fully connected and polling live OBD data.
  connected('OBD-II Connected'),

  /// A recoverable error occurred (will attempt reconnect).
  error('Connection Error');

  const ObdConnectionStatus(this.label);

  /// Human-readable label for the UI.
  final String label;

  /// Whether we are in any active/transitioning state.
  bool get isActive =>
      this == connected ||
      this == connecting ||
      this == initializing ||
      this == scanning;
}
