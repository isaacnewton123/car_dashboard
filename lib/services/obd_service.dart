/// OBD-II communication service over Bluetooth Classic (ELM327).
///
/// Uses a custom platform-channel [BluetoothClassicService] for RFCOMM/SPP
/// serial communication — no third-party Bluetooth library required.
///
/// Handles:
/// - Discovery of paired Bluetooth devices
/// - RFCOMM connection to the ELM327 adapter
/// - AT initialization sequence
/// - Two-tier PID polling: critical (RPM/Speed) every cycle,
///   normal PIDs round-robin one per cycle
/// - Shared-command deduplication (parse multiple PIDs from one response)
/// - Hex response parsing into typed values
/// - Auto-reconnection on disconnect
/// - DTC reading (Mode 03) and clearing (Mode 04)
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'bluetooth_classic_service.dart';
import 'obd_connection_state.dart';
import 'obd_pid.dart';

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

/// Target device name for auto-detection.
const String _kTargetDeviceName = 'OBDII';

/// Timeout for a single AT/PID command-response cycle.
const Duration _kCommandTimeout = Duration(milliseconds: 2000);

/// Delay between polling cycles — gives the ELM327 adapter breathing room.
/// Too low (< 20ms) causes cheap clones to buffer-overflow and hang.
const Duration _kCycleYieldDelay = Duration(milliseconds: 30);

/// Minimum delay between individual OBD commands within a cycle.
/// Prevents flooding the ELM327's tiny serial buffer.
const Duration _kInterCommandDelay = Duration(milliseconds: 30);

/// Number of consecutive failures before a PID is marked as unsupported.
/// Set high enough to survive protocol negotiation ("SEARCHING...") phase.
const int _kFailThreshold = 5;

/// ELM327 initialization commands sent after connection.
const List<String> _kInitCommands = [
  'ATZ',   // Reset
  'ATE0',  // Echo off
  'ATL0',  // Line feeds off
  'ATS0',  // Spaces off
  'ATSP0', // Auto-detect protocol
];

// ---------------------------------------------------------------------------
// Callback types
// ---------------------------------------------------------------------------

/// Called when a PID value is successfully parsed.
typedef PidValueCallback = void Function(ObdPid pid, double value);

/// Called when the connection status changes.
typedef StatusCallback = void Function(ObdConnectionStatus status, [String? errorMessage]);

/// Called when a raw OBD log entry is generated.
typedef LogCallback = void Function(String entry);

// ---------------------------------------------------------------------------
// Service
// ---------------------------------------------------------------------------

/// Manages the full lifecycle of an OBD-II Bluetooth Classic connection.
///
/// Uses a **two-tier polling architecture** for optimal latency:
/// - **Critical tier** (RPM + Speed): polled every cycle → ~100-200ms refresh
/// - **Normal tier** (all other PIDs): one per cycle, round-robin
///
/// Commands that map to multiple PIDs (e.g. `0115` → O2 voltage + fuel trim)
/// are sent once, and all sibling values are parsed from the single response.
class ObdService {
  ObdService({
    required this.onPidValue,
    required this.onStatusChange,
    this.onBatchComplete,
    this.onLog,
  }) {
    _buildCommandGroups();
  }

  /// Callback fired for each successfully parsed PID reading.
  final PidValueCallback onPidValue;

  /// Callback fired when the connection status transitions.
  final StatusCallback onStatusChange;

  /// Callback fired after each polling batch (critical + one normal).
  /// Use this to coalesce UI updates instead of rebuilding per-PID.
  final VoidCallback? onBatchComplete;

  /// Optional callback for raw OBD AT log entries.
  final LogCallback? onLog;

  // ---- Internal state ----

  final BluetoothClassicService _bluetooth = BluetoothClassicService();
  ObdConnectionStatus _status = ObdConnectionStatus.disconnected;
  bool _isPolling = false;
  bool _isSocketConnected = false;
  int _normalPidIndex = 0;
  final Set<ObdPid> _unsupportedPids = {};
  final Map<ObdPid, int> _failCounts = {};

  /// Maps a command string (e.g. `"0115"`) to all PIDs that share it.
  /// Used to parse multiple values from a single ELM327 response.
  final Map<String, List<ObdPid>> _commandGroups = {};

  /// Buffer for accumulating partial responses from the ELM327.
  final StringBuffer _responseBuffer = StringBuffer();

  /// Completer used to await a single command response.
  Completer<String>? _responseCompleter;

  /// Stream subscription for incoming Bluetooth data.
  StreamSubscription<Uint8List>? _inputSubscription;

  ObdConnectionStatus get status => _status;
  bool get isConnected => _status == ObdConnectionStatus.connected;

  // =========================================================================
  // COMMAND GROUP SETUP
  // =========================================================================

  /// Pre-compute command → PID[] mapping for shared-command deduplication.
  void _buildCommandGroups() {
    _commandGroups.clear();
    for (final ObdPid pid in ObdPids.all) {
      _commandGroups.putIfAbsent(pid.command, () => <ObdPid>[]).add(pid);
    }
  }

  // =========================================================================
  // PUBLIC API
  // =========================================================================

  /// Scan for paired Bluetooth devices.
  ///
  /// If no matching device is found, the returned list lets the caller
  /// present a manual picker.
  Future<List<BluetoothDeviceInfo>> discoverDevices() async {
    _setStatus(ObdConnectionStatus.scanning);
    try {
      final List<BluetoothDeviceInfo> bonded =
          await _bluetooth.getBondedDevices();
      return bonded;
    } catch (e) {
      _log('Discovery error: $e');
      _setStatus(ObdConnectionStatus.error);
      return [];
    }
  }

  /// Connect to a specific Bluetooth device and start polling.
  Future<bool> connect(BluetoothDeviceInfo device) async {
    _setStatus(ObdConnectionStatus.connecting);
    _log('Connecting to ${device.displayName} (${device.address})...');

    try {
      final bool connected = await _bluetooth.connect(device.address);
      if (!connected) {
        _log('RFCOMM connection returned false.');
        _setStatus(ObdConnectionStatus.error, 'Connection refused');
        return false;
      }

      _isSocketConnected = true;
      _log('RFCOMM connected.');

      // Listen to incoming data via EventChannel
      _inputSubscription = _bluetooth.listen(
        onData: _onDataReceived,
        onDone: _onDisconnected,
        onError: (Object error) {
          _log('Stream error: $error');
          _onDisconnected();
        },
      );

      // Initialize ELM327
      final bool initOk = await _initializeElm327();
      if (!initOk) {
        _log('ELM327 initialization failed.');
        await disconnect();
        return false;
      }

      _setStatus(ObdConnectionStatus.connected);
      _startPolling();
      return true;
    } catch (e) {
      _log('Connection error: $e');
      _setStatus(ObdConnectionStatus.error, e.toString());
      return false;
    }
  }

  /// Auto-connect: discover devices, find "OBDII", connect.
  Future<bool> autoConnect() async {
    final List<BluetoothDeviceInfo> devices = await discoverDevices();
    final BluetoothDeviceInfo? target =
        devices.cast<BluetoothDeviceInfo?>().firstWhere(
      (BluetoothDeviceInfo? d) =>
          d?.name
              .toUpperCase()
              .contains(_kTargetDeviceName.toUpperCase()) ??
          false,
      orElse: () => null,
    );

    if (target == null) {
      _log(
        'No "$_kTargetDeviceName" device found among '
        '${devices.length} paired devices.',
      );
      _setStatus(ObdConnectionStatus.disconnected);
      return false;
    }

    _log('Found "${target.displayName}" — auto-connecting...');
    return connect(target);
  }

  /// Gracefully disconnect and stop polling.
  Future<void> disconnect() async {
    _isPolling = false;
    _isSocketConnected = false;
    _normalPidIndex = 0;
    _unsupportedPids.clear();
    _failCounts.clear();

    await _inputSubscription?.cancel();
    _inputSubscription = null;

    try {
      await _bluetooth.disconnect();
    } catch (_) {
      // Ignore close errors
    }

    _setStatus(ObdConnectionStatus.disconnected);
    _log('Disconnected.');
  }

  /// Read Diagnostic Trouble Codes (Mode 03).
  Future<List<String>> readDtcCodes() async {
    if (!isConnected) return [];

    final String response = await _sendCommand('03');
    if (response.isEmpty || response.contains('NO DATA')) return [];

    return _parseDtcResponse(response);
  }

  /// Clear Diagnostic Trouble Codes (Mode 04).
  Future<bool> clearDtcCodes() async {
    if (!isConnected) return false;

    final String response = await _sendCommand('04');
    _log('Clear DTCs response: $response');
    return response.contains('44') || response.contains('OK');
  }

  /// Clean up resources.
  void dispose() {
    _isPolling = false;
    _isSocketConnected = false;
    _inputSubscription?.cancel();
    _bluetooth.dispose();
  }

  // =========================================================================
  // ELM327 INITIALIZATION
  // =========================================================================

  Future<bool> _initializeElm327() async {
    _setStatus(ObdConnectionStatus.initializing);

    for (final String cmd in _kInitCommands) {
      final String response = await _sendCommand(cmd);
      _log('$cmd → $response');

      // ATZ should return "ELM327" in its response
      if (cmd == 'ATZ' && !response.toUpperCase().contains('ELM')) {
        // Some adapters need a second reset
        final String retry = await _sendCommand('ATZ');
        if (!retry.toUpperCase().contains('ELM')) {
          _log('Warning: ATZ did not return ELM identifier.');
          // Continue anyway — some clones don't identify properly
        }
      }

      await Future.delayed(const Duration(milliseconds: 150));
    }

    // ── Protocol warm-up ─────────────────────────────────────────────
    // After ATSP0 (auto-detect), the ELM327 needs to negotiate the
    // vehicle's OBD protocol. Sending "0100" (Supported PIDs) triggers
    // this negotiation. The first response will be "SEARCHING..." or
    // slow — this is normal. Without this warm-up, the first real PID
    // queries would all timeout and get falsely marked unsupported.
    _log('Protocol warm-up: sending 0100...');
    final String warmup1 = await _sendCommand('0100');
    _log('0100 → $warmup1');
    await Future.delayed(const Duration(milliseconds: 200));

    // Send a second warm-up to confirm protocol is locked in.
    final String warmup2 = await _sendCommand('0100');
    _log('0100 (confirm) → $warmup2');
    await Future.delayed(const Duration(milliseconds: 100));

    // Fetch one-time PIDs (e.g. Warm-ups, OBD Compliance)
    for (final ObdPid pid in ObdPids.oneTimePulls) {
      await _pollSinglePid(pid);
      await Future.delayed(const Duration(milliseconds: 80));
    }

    return true;
  }

  // =========================================================================
  // TWO-TIER POLLING LOOP
  // =========================================================================

  void _startPolling() {
    _isPolling = true;
    _normalPidIndex = 0;
    _pollLoop();
  }

  /// Two-tier polling loop optimised for real-time RPM + Speed:
  ///
  ///  1. **Critical** (RPM + Speed) — polled every cycle
  ///  2. **Normal** — one unique command per cycle, round-robin
  ///
  /// Estimated cycle time with typical ELM327 adapter:
  ///   RPM (~80ms) + Speed (~80ms) + 1 normal (~80ms) ≈ 240ms
  ///   → RPM/Speed refreshed every ~240ms
  Future<void> _pollLoop() async {
    final List<ObdPid> normalPids = ObdPids.normalPeriodicUniqueCommands;

    while (_isPolling && _isSocketConnected) {
      try {
        // ── TIER 1: Critical PIDs (every cycle) ──────────────────────
        for (final ObdPid pid in ObdPids.criticalPids) {
          if (_unsupportedPids.contains(pid)) continue;
          await _pollSinglePid(pid);
          await Future.delayed(_kInterCommandDelay);
        }

        // Notify UI immediately after critical data (RPM + Speed).
        onBatchComplete?.call();

        // ── TIER 2: One normal PID per cycle (round-robin) ───────────
        if (normalPids.isNotEmpty) {
          int attempts = 0;
          while (attempts < normalPids.length) {
            final ObdPid pid =
                normalPids[_normalPidIndex % normalPids.length];
            _normalPidIndex++;
            attempts++;

            if (_unsupportedPids.contains(pid)) continue;

            // Send the command once and parse ALL sibling PIDs
            await _pollPidGroup(pid);
            onBatchComplete?.call();
            break;
          }
        }

        // Minimal yield to let the event loop breathe.
        await Future.delayed(_kCycleYieldDelay);
      } catch (e) {
        _log('Polling loop error: $e');
        await Future.delayed(const Duration(milliseconds: 200));
      }
    }
    _isPolling = false;
  }

  // =========================================================================
  // PID POLLING
  // =========================================================================

  /// Poll a single PID (no sibling dedup).
  /// Used for critical PIDs and one-time initialization pulls.
  Future<void> _pollSinglePid(ObdPid pid) async {
    if (_unsupportedPids.contains(pid)) return;

    final String response = await _sendCommand(pid.command);

    // Skip transient adapter responses (protocol negotiation, busy)
    if (_isTransientResponse(response)) return;

    if (response.isEmpty ||
        response.contains('NO DATA') ||
        response.contains('ERROR')) {
      _failCounts[pid] = (_failCounts[pid] ?? 0) + 1;
      if (_failCounts[pid]! >= _kFailThreshold) {
        _log('PID ${pid.name} marked unsupported ($_kFailThreshold consecutive failures).');
        _unsupportedPids.add(pid);
      }
      return;
    }

    final List<int>? dataBytes = _parseHexResponse(response, pid);
    if (dataBytes == null || dataBytes.length < pid.responseBytes) {
      _failCounts[pid] = (_failCounts[pid] ?? 0) + 1;
      if (_failCounts[pid]! >= _kFailThreshold) {
        _log('PID ${pid.name} marked unsupported (invalid data after $_kFailThreshold tries).');
        _unsupportedPids.add(pid);
      }
      return;
    }

    _failCounts[pid] = 0;

    try {
      final double value = pid.parse(dataBytes);
      onPidValue(pid, value);
    } catch (e) {
      _log('Parse error for ${pid.name}: $e (raw: $response)');
    }
  }

  /// Poll a command and parse ALL sibling PIDs that share the same command.
  ///
  /// For example, command `"0115"` maps to both O2 voltage and O2 fuel trim.
  /// Sending it once and parsing both values eliminates a redundant round-trip.
  Future<void> _pollPidGroup(ObdPid primaryPid) async {
    if (_unsupportedPids.contains(primaryPid)) return;

    final String response = await _sendCommand(primaryPid.command);
    // Skip transient adapter responses
    if (_isTransientResponse(response)) return;

    if (response.isEmpty ||
        response.contains('NO DATA') ||
        response.contains('ERROR')) {
      // Mark ALL siblings as failed
      final List<ObdPid> siblings =
          _commandGroups[primaryPid.command] ?? <ObdPid>[primaryPid];
      for (final ObdPid sibling in siblings) {
        _failCounts[sibling] = (_failCounts[sibling] ?? 0) + 1;
        if (_failCounts[sibling]! >= _kFailThreshold) {
          _log('PID ${sibling.name} marked unsupported.');
          _unsupportedPids.add(sibling);
        }
      }
      return;
    }

    // Parse ALL PIDs sharing this command from the single response.
    final List<ObdPid> siblings =
        _commandGroups[primaryPid.command] ?? <ObdPid>[primaryPid];
    for (final ObdPid sibling in siblings) {
      final List<int>? dataBytes = _parseHexResponse(response, sibling);
      if (dataBytes == null || dataBytes.length < sibling.responseBytes) {
        _failCounts[sibling] = (_failCounts[sibling] ?? 0) + 1;
        if (_failCounts[sibling]! >= _kFailThreshold) {
          _unsupportedPids.add(sibling);
        }
        continue;
      }

      _failCounts[sibling] = 0;
      try {
        final double value = sibling.parse(dataBytes);
        onPidValue(sibling, value);
      } catch (e) {
        _log('Parse error for ${sibling.name}: $e (raw: $response)');
      }
    }
  }

  // =========================================================================
  // COMMAND / RESPONSE
  // =========================================================================

  /// Send a command to the ELM327 and wait for the `>` prompt response.
  Future<String> _sendCommand(String command) async {
    if (!_isSocketConnected) return '';

    // Cancel any pending response
    if (_responseCompleter != null && !_responseCompleter!.isCompleted) {
      _responseCompleter!.completeError(TimeoutException('Cancelled'));
    }
    _responseCompleter = Completer<String>();
    _responseBuffer.clear();

    try {
      await _bluetooth.writeString('$command\r');

      final String response = await _responseCompleter!.future
          .timeout(_kCommandTimeout, onTimeout: () {
        _log('Timeout waiting for response to: $command');
        return _responseBuffer.toString();
      });

      return response.trim();
    } catch (e) {
      if (e is! TimeoutException) {
        _log('Send error: $e');
      }
      return '';
    }
  }

  /// Called when raw bytes arrive from the Bluetooth connection.
  void _onDataReceived(Uint8List data) {
    final String chunk = utf8.decode(data, allowMalformed: true);
    _responseBuffer.write(chunk);

    // ELM327 signals end of response with '>'
    if (chunk.contains('>')) {
      final String fullResponse = _responseBuffer
          .toString()
          .replaceAll('>', '')
          .replaceAll('\r', '')
          .replaceAll('\n', '')
          .trim();

      if (_responseCompleter != null && !_responseCompleter!.isCompleted) {
        _responseCompleter!.complete(fullResponse);
      }
      _responseBuffer.clear();
    }
  }

  // =========================================================================
  // PARSING
  // =========================================================================

  /// Extract data bytes from a hex response string.
  ///
  /// Example: `"410C1AF8"` → strips `"41 0C"` header → `[0x1A, 0xF8]`
  List<int>? _parseHexResponse(String response, ObdPid pid) {
    // Remove any non-hex characters
    final String cleaned = response.replaceAll(RegExp(r'[^0-9A-Fa-f]'), '');

    // Find the response header: "41" + PID hex
    final String pidHex =
        pid.id.toRadixString(16).toUpperCase().padLeft(2, '0');
    final String header = '41$pidHex';
    final int headerIdx = cleaned.toUpperCase().indexOf(header);

    if (headerIdx == -1) return null;

    // Data starts after the header (4 chars: "41" + 2 PID chars)
    final int dataStart = headerIdx + header.length;
    final int dataEnd = dataStart + (pid.responseBytes * 2);

    if (dataEnd > cleaned.length) return null;

    final String dataHex = cleaned.substring(dataStart, dataEnd);
    final List<int> bytes = <int>[];
    for (int i = 0; i < dataHex.length; i += 2) {
      bytes.add(int.parse(dataHex.substring(i, i + 2), radix: 16));
    }

    return bytes;
  }

  /// Parse Mode 03 DTC response into DTC code strings.
  List<String> _parseDtcResponse(String response) {
    final String cleaned = response.replaceAll(RegExp(r'[^0-9A-Fa-f]'), '');
    final List<String> codes = [];

    // Skip header "43", then every 4 hex chars is a DTC
    int idx = cleaned.toUpperCase().indexOf('43');
    if (idx == -1) return codes;
    idx += 2; // skip "43"

    while (idx + 4 <= cleaned.length) {
      final int byte1 =
          int.parse(cleaned.substring(idx, idx + 2), radix: 16);
      final int byte2 =
          int.parse(cleaned.substring(idx + 2, idx + 4), radix: 16);

      if (byte1 == 0 && byte2 == 0) {
        idx += 4;
        continue; // padding
      }

      // First 2 bits = type (P/C/B/U), next 2 bits = first digit
      const List<String> types = ['P', 'C', 'B', 'U'];
      final String type = types[(byte1 >> 6) & 0x03];
      final String digit1 = ((byte1 >> 4) & 0x03).toString();
      final String digit2 = (byte1 & 0x0F).toRadixString(16).toUpperCase();
      final String lastTwo =
          byte2.toRadixString(16).toUpperCase().padLeft(2, '0');

      codes.add('$type$digit1$digit2$lastTwo');
      idx += 4;
    }

    return codes;
  }

  // =========================================================================
  // HELPERS
  // =========================================================================

  /// Returns `true` if the response is a transient ELM327 adapter message
  /// (e.g. protocol negotiation) that should be silently skipped — NOT counted
  /// as a PID failure.
  bool _isTransientResponse(String response) {
    final String upper = response.toUpperCase();
    return upper.contains('SEARCHING') ||
        upper.contains('BUS BUSY') ||
        upper.contains('BUS INIT') ||
        upper.contains('UNABLE TO CONNECT') ||
        upper.contains('CAN ERROR') ||
        upper.contains('STOPPED');
  }

  void _onDisconnected() {
    _log('Bluetooth disconnected.');
    _isPolling = false;
    _isSocketConnected = false;
    _normalPidIndex = 0;
    _unsupportedPids.clear();
    _failCounts.clear();
    _setStatus(ObdConnectionStatus.disconnected);
  }

  void _setStatus(ObdConnectionStatus newStatus, [String? errorMessage]) {
    if (_status == newStatus && newStatus != ObdConnectionStatus.error) return;
    _status = newStatus;
    onStatusChange(newStatus, errorMessage);
  }

  void _log(String message) {
    debugPrint('[OBD] $message');
    final String timestamp =
        DateTime.now().toIso8601String().substring(11, 19);
    onLog?.call('[$timestamp] $message');
  }
}
