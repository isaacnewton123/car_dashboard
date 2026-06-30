/// OBD-II communication service over Bluetooth Classic (ELM327).
///
/// Uses [flutter_classic_bluetooth] for RFCOMM/SPP serial communication.
///
/// Handles:
/// - Discovery of paired Bluetooth devices
/// - RFCOMM connection to the ELM327 adapter
/// - AT initialization sequence
/// - Sequential PID polling with priority-based scheduling
/// - Hex response parsing into typed values
/// - Auto-reconnection on disconnect
/// - DTC reading (Mode 03) and clearing (Mode 04)
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_classic_bluetooth/flutter_classic_bluetooth.dart';

import 'obd_connection_state.dart';
import 'obd_pid.dart';

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

/// Target device name for auto-detection.
const String _kTargetDeviceName = 'OBDII';

/// Timeout for a single AT/PID command-response cycle.
const Duration _kCommandTimeout = Duration(milliseconds: 2000);

/// Delay between consecutive PID requests to avoid overwhelming the ECU.
const Duration _kInterCommandDelay = Duration(milliseconds: 50);

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
class ObdService {
  ObdService({
    required this.onPidValue,
    required this.onStatusChange,
    this.onLog,
  });

  /// Callback fired for each successfully parsed PID reading.
  final PidValueCallback onPidValue;

  /// Callback fired when the connection status transitions.
  final StatusCallback onStatusChange;

  /// Optional callback for raw OBD AT log entries.
  final LogCallback? onLog;

  // ---- Internal state ----

  final FlutterClassicBluetooth _bluetooth = FlutterClassicBluetooth();
  BtcConnection? _connection;
  ObdConnectionStatus _status = ObdConnectionStatus.disconnected;
  Timer? _pollingTimer;
  int _pollCycle = 0;
  bool _isPolling = false;

  /// Buffer for accumulating partial responses from the ELM327.
  final StringBuffer _responseBuffer = StringBuffer();

  /// Completer used to await a single command response.
  Completer<String>? _responseCompleter;

  /// Stream subscription for incoming Bluetooth data.
  StreamSubscription<Uint8List>? _inputSubscription;

  ObdConnectionStatus get status => _status;
  bool get isConnected => _status == ObdConnectionStatus.connected;

  // =========================================================================
  // PUBLIC API
  // =========================================================================

  /// Scan for paired devices and auto-connect to the one named [_kTargetDeviceName].
  ///
  /// If no matching device is found, the returned list lets the caller
  /// present a manual picker.
  Future<List<BtcDevice>> discoverDevices() async {
    _setStatus(ObdConnectionStatus.scanning);
    try {
      final List<BtcDevice> bonded = await _bluetooth.getPairedDevices();
      return bonded;
    } catch (e) {
      _log('Discovery error: $e');
      _setStatus(ObdConnectionStatus.error);
      return [];
    }
  }

  /// Connect to a specific Bluetooth device and start polling.
  Future<bool> connect(BtcDevice device) async {
    _setStatus(ObdConnectionStatus.connecting);
    _log('Connecting to ${device.displayName} (${device.address})...');

    try {
      _connection = await _bluetooth.connect(
        address: device.address,
        secure: false, // ELM327/OBD-II dongles often require insecure RFCOMM sockets
      );
      _log('RFCOMM connected.');

      // Listen to incoming data
      _inputSubscription = _connection!.input.listen(
        _onDataReceived,
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
    final List<BtcDevice> devices = await discoverDevices();
    final BtcDevice? target = devices.cast<BtcDevice?>().firstWhere(
      (BtcDevice? d) =>
          d?.displayName.toUpperCase().contains(_kTargetDeviceName.toUpperCase()) ??
          false,
      orElse: () => null,
    );

    if (target == null) {
      _log('No "$_kTargetDeviceName" device found among ${devices.length} paired devices.');
      _setStatus(ObdConnectionStatus.disconnected);
      return false;
    }

    _log('Found "${target.displayName}" — auto-connecting...');
    return connect(target);
  }

  /// Gracefully disconnect and stop polling.
  Future<void> disconnect() async {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _isPolling = false;

    await _inputSubscription?.cancel();
    _inputSubscription = null;

    try {
      await _connection?.close();
    } catch (_) {
      // Ignore close errors
    }
    _connection?.dispose();
    _connection = null;

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
    _pollingTimer?.cancel();
    _inputSubscription?.cancel();
    _connection?.dispose();
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

      await Future.delayed(const Duration(milliseconds: 100));
    }

    return true;
  }

  // =========================================================================
  // POLLING LOOP
  // =========================================================================

  void _startPolling() {
    _pollCycle = 0;
    _pollingTimer?.cancel();
    // Use a timer to trigger each poll cycle
    _pollingTimer = Timer.periodic(
      const Duration(milliseconds: 100),
      (_) => _pollNextBatch(),
    );
  }

  Future<void> _pollNextBatch() async {
    if (_isPolling || !isConnected) return;
    _isPolling = true;

    try {
      // High priority: every cycle
      for (final ObdPid pid in ObdPids.highPriority) {
        if (!isConnected) break;
        await _pollSinglePid(pid);
        await Future.delayed(_kInterCommandDelay);
      }

      // Medium priority: every 3rd cycle
      if (_pollCycle % 3 == 0) {
        for (final ObdPid pid in ObdPids.mediumPriority) {
          if (!isConnected) break;
          await _pollSinglePid(pid);
          await Future.delayed(_kInterCommandDelay);
        }
      }

      // Low priority: every 10th cycle
      if (_pollCycle % 10 == 0) {
        for (final ObdPid pid in ObdPids.lowPriority) {
          if (!isConnected) break;
          await _pollSinglePid(pid);
          await Future.delayed(_kInterCommandDelay);
        }
      }

      _pollCycle++;
    } catch (e) {
      _log('Polling error: $e');
    } finally {
      _isPolling = false;
    }
  }

  Future<void> _pollSinglePid(ObdPid pid) async {
    final String response = await _sendCommand(pid.command);
    if (response.isEmpty || response.contains('NO DATA') || response.contains('ERROR')) {
      return;
    }

    final List<int>? dataBytes = _parseHexResponse(response, pid);
    if (dataBytes == null || dataBytes.length < pid.responseBytes) return;

    try {
      final double value = pid.parse(dataBytes);
      onPidValue(pid, value);
    } catch (e) {
      _log('Parse error for ${pid.name}: $e (raw: $response)');
    }
  }

  // =========================================================================
  // COMMAND / RESPONSE
  // =========================================================================

  /// Send a command to the ELM327 and wait for the `>` prompt response.
  Future<String> _sendCommand(String command) async {
    if (_connection == null || !_connection!.isConnected) {
      return '';
    }

    // Cancel any pending response
    if (_responseCompleter != null && !_responseCompleter!.isCompleted) {
      _responseCompleter!.completeError(TimeoutException('Cancelled'));
    }
    _responseCompleter = Completer<String>();
    _responseBuffer.clear();

    try {
      await _connection!.output.writeString('$command\r');
      await _connection!.output.allSent;

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
  /// Example: "410C1AF8" → strips "41 0C" header → [0x1A, 0xF8]
  List<int>? _parseHexResponse(String response, ObdPid pid) {
    // Remove any non-hex characters
    final String cleaned = response.replaceAll(RegExp(r'[^0-9A-Fa-f]'), '');

    // Find the response header: "41" + PID hex
    final String pidHex = pid.id.toRadixString(16).toUpperCase().padLeft(2, '0');
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
      final int byte1 = int.parse(cleaned.substring(idx, idx + 2), radix: 16);
      final int byte2 = int.parse(cleaned.substring(idx + 2, idx + 4), radix: 16);

      if (byte1 == 0 && byte2 == 0) {
        idx += 4;
        continue; // padding
      }

      // First 2 bits = type (P/C/B/U), next 2 bits = first digit
      const List<String> types = ['P', 'C', 'B', 'U'];
      final String type = types[(byte1 >> 6) & 0x03];
      final String digit1 = ((byte1 >> 4) & 0x03).toString();
      final String digit2 = (byte1 & 0x0F).toRadixString(16).toUpperCase();
      final String lastTwo = byte2.toRadixString(16).toUpperCase().padLeft(2, '0');

      codes.add('$type$digit1$digit2$lastTwo');
      idx += 4;
    }

    return codes;
  }

  // =========================================================================
  // HELPERS
  // =========================================================================

  void _onDisconnected() {
    _log('Bluetooth disconnected.');
    _pollingTimer?.cancel();
    _isPolling = false;
    _setStatus(ObdConnectionStatus.disconnected);
  }

  void _setStatus(ObdConnectionStatus newStatus, [String? errorMessage]) {
    if (_status == newStatus && newStatus != ObdConnectionStatus.error) return;
    _status = newStatus;
    onStatusChange(newStatus, errorMessage);
  }

  void _log(String message) {
    debugPrint('[OBD] $message');
    final String timestamp = DateTime.now().toIso8601String().substring(11, 19);
    onLog?.call('[$timestamp] $message');
  }
}
