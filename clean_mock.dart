import 'dart:io';

void main() {
  final file = File('lib/providers/dashboard_provider.dart');
  String code = file.readAsStringSync();

  // 1. kMockTickInterval
  code = code.replaceAll(RegExp(r'const Duration _kMockTickInterval.*?;\n'), '');

  // 2. startMockDataSimulation call in constructor
  code = code.replaceAll(RegExp(r'\s*// Start in mock mode.*?startMockDataSimulation\(\);\n'), '\n');

  // 3. connectObd
  code = code.replaceAll(RegExp(r'Future<bool> connectObd\(\) async \{.*?\n\s*\}', dotAll: true), 'Future<bool> connectObd() async {\n    return _obdService.autoConnect();\n  }');

  // 4. connectObdToDevice
  code = code.replaceAll(RegExp(r'Future<bool> connectObdToDevice\(BtcDevice device\) async \{.*?\n\s*\}', dotAll: true), 'Future<bool> connectObdToDevice(BtcDevice device) async {\n    return _obdService.connect(device);\n  }');

  // 5. disconnectObd
  code = code.replaceAll(RegExp(r'Future<void> disconnectObd\(\) async \{\n\s*await _obdService\.disconnect\(\);\n\s*startMockDataSimulation\(\);\n\s*\}'), 'Future<void> disconnectObd() async {\n    await _obdService.disconnect();\n  }');

  // 6. _onObdStatusChange
  code = code.replaceAll(RegExp(r'if \(status == ObdConnectionStatus\.disconnected && _mockTimer == null\) \{\s*// OBD disconnected — fall back to mock\s*startMockDataSimulation\(\);\s*\}\n'), '');

  // 7. _updateTripData distance
  code = code.replaceAll('final double distanceIncrement =\n        _speed / 3600.0 * (_kMockTickInterval.inMilliseconds / 1000.0);', 'final double distanceIncrement = 0.0; // Distance logic requires time delta tracking (implement later if needed)');

  // 8. _updateTripData fuel economy mock
  code = code.replaceAll(RegExp(r'\} else if \(\!isLiveObd\) \{.*?\}', dotAll: true), '}');

  // 9. _mockGForce
  code = code.replaceAll(RegExp(r'double _mockGForce = 0\.0;\n'), '');
  code = code.replaceAll(RegExp(r'double get mockGForce => _mockGForce;\n'), '');
  code = code.replaceAll(RegExp(r'\s*// Mock G-force: based on speed change rate\n\s*_mockGForce = sin\(_mockPhase \* 2\) \* 0\.4;\n'), '');

  // 10. refreshDtcCodes
  code = code.replaceAll(RegExp(r'Future<void> refreshDtcCodes\(\) async \{\n\s*if \(isLiveObd\) \{'), 'Future<void> refreshDtcCodes() async {\n    if (isLiveObd) {');

  // 11. clearDtcCodes mock
  final clearDtcReplacement = '''  void clearDtcCodes() {
    if (isLiveObd) {
      clearRealDtcCodes().then((_) {
        _dtcCodes = [];
        final String timestamp =
            DateTime.now().toIso8601String().substring(11, 19);
        _obdLog.add('[\$timestamp] > 04\\\\r  →  DTCs cleared (ECU)');
        notifyListeners();
      });
    }
  }''';
  code = code.replaceAll(RegExp(r'void clearDtcCodes\(\) \{.*?\}\n  \}', dotAll: true), clearDtcReplacement);

  // 12. _addObdLogEntry mock
  code = code.replaceAll(RegExp(r'void _addObdLogEntry\(\) \{.*?\n  \}', dotAll: true), 'void _addObdLogEntry() {}');

  // 13. dispose mock timer
  code = code.replaceAll(RegExp(r'\s*_mockTimer\?\.cancel\(\);\n'), '\n');

  // 14. REMOVE ENTIRE MOCK SIMULATION BLOCK
  code = code.replaceAll(RegExp(r'\s*// =========================================================================\n\s*// MOCK SIMULATION.*?void stopMockDataSimulation\(\) \{.*?\n  \}', dotAll: true), '');

  file.writeAsStringSync(code);
}
