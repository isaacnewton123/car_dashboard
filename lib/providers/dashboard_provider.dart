import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_classic_bluetooth/flutter_classic_bluetooth.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../models/dtc_code.dart';
import '../models/gemini_model.dart';
import '../services/obd_connection_state.dart';
import '../services/obd_pid.dart';
import '../services/obd_service.dart';

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const String _kApiKeyPref = 'gemini_api_key';
const String _kModelIdPref = 'gemini_model_id';
const String _kUnitPref = 'speed_unit'; // "kmh" | "mph"


/// Speed unit preference.
enum SpeedUnit {
  kmh('km/h'),
  mph('mph');

  const SpeedUnit(this.label);
  final String label;
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

/// Central state manager for the Car Dashboard head unit.
class DashboardProvider extends ChangeNotifier {
  DashboardProvider() {
    _speechToText = stt.SpeechToText();
    _flutterTts = FlutterTts();
    _initTts();
    loadSettings();

    // Initialize OBD service
    _obdService = ObdService(
      onPidValue: _onPidValue,
      onStatusChange: _onObdStatusChange,
      onLog: _onObdLog,
    );
  }

  // =========================================================================
  // OBD-II SERVICE
  // =========================================================================

  late final ObdService _obdService;
  ObdConnectionStatus _obdStatus = ObdConnectionStatus.disconnected;
  String? _obdErrorMessage;

  ObdConnectionStatus get obdStatus => _obdStatus;
  String? get obdErrorMessage => _obdErrorMessage;
  ObdService get obdService => _obdService;

  /// Whether we are receiving live data from the OBD adapter.
  bool get isLiveObd => _obdStatus == ObdConnectionStatus.connected;

  /// Connect to the OBD adapter (auto-detect "OBDII" device).
  Future<bool> connectObd() async {
    return _obdService.autoConnect();
  }

  /// Connect to a specific Bluetooth device.
  Future<bool> connectObdToDevice(BtcDevice device) async {
    return _obdService.connect(device);
  }

  /// Disconnect from the OBD adapter.
  Future<void> disconnectObd() async {
    await _obdService.disconnect();
  }

  /// Discover paired Bluetooth devices.
  Future<List<BtcDevice>> discoverObdDevices() async {
    return _obdService.discoverDevices();
  }

  /// Read real DTCs from the ECU.
  Future<List<String>> readRealDtcCodes() async {
    return _obdService.readDtcCodes();
  }

  /// Clear real DTCs on the ECU.
  Future<bool> clearRealDtcCodes() async {
    return _obdService.clearDtcCodes();
  }

  void _onObdStatusChange(ObdConnectionStatus status, [String? errorMessage]) {
    _obdStatus = status;
    if (errorMessage != null) _obdErrorMessage = errorMessage;
    _isConnected = status == ObdConnectionStatus.connected;

    notifyListeners();
  }

  void _onObdLog(String entry) {
    _obdLog.add(entry);
    // Keep last 100 entries
    if (_obdLog.length > 100) {
      _obdLog.removeRange(0, _obdLog.length - 100);
    }
  }

  /// Called by [ObdService] whenever a PID value is parsed.
  void _onPidValue(ObdPid pid, double value) {
    switch (pid.id) {
      case 0x0C:
        _rpm = value.round();
      case 0x0D:
        _speed = value.round();
      case 0x04:
        _engineLoad = value.round();
      case 0x05:
        _coolantTemp = value.round();
      case 0x06:
        _shortTermFuelTrim = value;
        _fuelTrim = value;
      case 0x07:
        _longTermFuelTrim = value;
      case 0x0E:
        _ignitionTiming = value;
      case 0x0F:
        _intakeAirTemp = value.round();
      case 0x10:
        _mafAirFlow = value;
        // Calculate fuel rate from MAF: L/h ≈ MAF (g/s) / 14.7 / 750 * 3600
        _fuelRate = (value / 14.7 / 750.0 * 3600.0).clamp(0.0, 50.0);
      case 0x11:
        _throttlePosition = value.round();
      case 0x19:
        if (pid.name.contains('Voltage')) {
          _o2SensorVoltage = value;
        } else {
          _o2SensorB1S2FuelTrim = value;
        }
      case 0x1C:
        _obdCompliance = value.round();
      case 0x1F:
        _timeSinceEngineStart = value.round();
      case 0x21:
        _distanceWithMil = value.round();
      case 0x24:
        if (pid.name.contains('Voltage')) {
          _o2WrVoltageB1S1 = value;
        } else {
          _lambdaO2B1S1 = value;
        }
      case 0x2E:
        _commandedEvapPurge = value;
      case 0x30:
        _warmupsSinceReset = value.round();
      case 0x31:
        _distanceSinceReset = value.round();
      case 0x33:
        _barometricPressure = value.round();
      case 0x34:
        if (pid.name.contains('Current')) {
          _o2CurrentB1S1 = value;
        } else {
          _lambdaO2CurrentB1S1 = value;
        }
      case 0x3C:
        _catTempB1S1 = value;
      case 0x3E:
        _catTempB1S2 = value;
      case 0x42:
        _batteryVoltage = value;
      case 0x43:
        _absoluteEngineLoad = value;
      case 0x44:
        _commandedEquivRatio = value;
      case 0x45:
        _relativeThrottlePos = value;
      case 0x47:
        _absThrottlePosB = value;
      case 0x49:
        _absThrottlePosD = value;
      case 0x4A:
        _absThrottlePosE = value;
      case 0x4C:
        _throttleActuatorCtrl = value;
      case 0x4D:
        _engineRunTimeWithMil = value.round();
      case 0x4E:
        _timeSinceDtcCleared = value.round();
    }

    _updateTripData();
    _updatePerformanceTracking();

    notifyListeners();
  }

  // =========================================================================
  // OBD-II TELEMETRY
  // =========================================================================

  int _speed = 0;
  int _rpm = 0;
  int _coolantTemp = 0;
  bool _isConnected = false;
  int _engineLoad = 0;
  int _intakeAirTemp = 0;
  double _batteryVoltage = 0.0;
  int _gear = 0; 
  int _throttlePosition = 0;
  double _fuelRate = 0.0;
  double _fuelTrim = 0.0;
  double _o2SensorVoltage = 0.0;
  double _shortTermFuelTrim = 0.0;
  double _longTermFuelTrim = 0.0;
  double _ignitionTiming = 0.0;
  double _mafAirFlow = 0.0;
  int _obdCompliance = 0;
  int _timeSinceEngineStart = 0;
  int _distanceWithMil = 0;
  double _o2WrVoltageB1S1 = 0.0;
  double _lambdaO2B1S1 = 1.0;
  double _o2SensorB1S2FuelTrim = 0.0;
  double _commandedEvapPurge = 0.0;
  int _warmupsSinceReset = 0;
  int _distanceSinceReset = 0;
  int _barometricPressure = 101;
  double _o2CurrentB1S1 = 0.0;
  double _lambdaO2CurrentB1S1 = 1.0;
  double _catTempB1S1 = 0.0;
  double _catTempB1S2 = 0.0;
  double _absoluteEngineLoad = 0.0;
  double _commandedEquivRatio = 1.0;
  double _relativeThrottlePos = 0.0;
  double _absThrottlePosB = 0.0;
  double _absThrottlePosD = 0.0;
  double _absThrottlePosE = 0.0;
  double _throttleActuatorCtrl = 0.0;
  int _engineRunTimeWithMil = 0;
  int _timeSinceDtcCleared = 0;

  int get speed => _speed;
  int get rpm => _rpm;
  int get coolantTemp => _coolantTemp;
  bool get isConnected => _isConnected;
  int get engineLoad => _engineLoad;
  int get intakeAirTemp => _intakeAirTemp;
  double get batteryVoltage => _batteryVoltage;
  int get gear => _gear;
  int get throttlePosition => _throttlePosition;
  double get fuelRate => _fuelRate;
  double get fuelTrim => _fuelTrim;
  double get o2SensorVoltage => _o2SensorVoltage;
  double get shortTermFuelTrim => _shortTermFuelTrim;
  double get longTermFuelTrim => _longTermFuelTrim;
  double get ignitionTiming => _ignitionTiming;
  double get mafAirFlow => _mafAirFlow;
  int get obdCompliance => _obdCompliance;
  int get timeSinceEngineStart => _timeSinceEngineStart;
  int get distanceWithMil => _distanceWithMil;
  double get o2WrVoltageB1S1 => _o2WrVoltageB1S1;
  double get lambdaO2B1S1 => _lambdaO2B1S1;
  double get o2SensorB1S2FuelTrim => _o2SensorB1S2FuelTrim;
  double get commandedEvapPurge => _commandedEvapPurge;
  int get warmupsSinceReset => _warmupsSinceReset;
  int get distanceSinceReset => _distanceSinceReset;
  int get barometricPressure => _barometricPressure;
  double get o2CurrentB1S1 => _o2CurrentB1S1;
  double get lambdaO2CurrentB1S1 => _lambdaO2CurrentB1S1;
  double get catTempB1S1 => _catTempB1S1;
  double get catTempB1S2 => _catTempB1S2;
  double get absoluteEngineLoad => _absoluteEngineLoad;
  double get commandedEquivRatio => _commandedEquivRatio;
  double get relativeThrottlePos => _relativeThrottlePos;
  double get absThrottlePosB => _absThrottlePosB;
  double get absThrottlePosD => _absThrottlePosD;
  double get absThrottlePosE => _absThrottlePosE;
  double get throttleActuatorCtrl => _throttleActuatorCtrl;
  int get engineRunTimeWithMil => _engineRunTimeWithMil;
  int get timeSinceDtcCleared => _timeSinceDtcCleared;

  int get displaySpeed {
    if (_speedUnit == SpeedUnit.mph) {
      return (_speed * 0.621371).round();
    }
    return _speed;
  }

  // =========================================================================
  // TRIP COMPUTER
  // =========================================================================

  double _tripDistance = 0.0; // km
  DateTime _tripStartTime = DateTime.now();
  DateTime _lastTripUpdateTime = DateTime.now();
  double _averageSpeed = 0.0;
  double _fuelEconomy = 0.0; // L/100km
  int _tripMaxSpeed = 0;
  int _speedSampleCount = 0;
  double _speedSampleSum = 0.0;

  double get tripDistance => _tripDistance;
  Duration get tripTime => DateTime.now().difference(_tripStartTime);
  double get averageSpeed => _averageSpeed;
  double get fuelEconomy => _fuelEconomy;
  int get tripMaxSpeed => _tripMaxSpeed;

  void _updateTripData() {
    final now = DateTime.now();
    final double dt = now.difference(_lastTripUpdateTime).inMilliseconds / 1000.0;
    _lastTripUpdateTime = now;

    // Distance: speed (km/h) × dt (seconds) converted to km
    final double distanceIncrement = _speed / 3600.0 * dt;
    _tripDistance += distanceIncrement;

    if (_speed > 0) {
      _speedSampleCount++;
      _speedSampleSum += _speed;
      _averageSpeed = _speedSampleSum / _speedSampleCount;
    }

    if (_speed > _tripMaxSpeed) {
      _tripMaxSpeed = _speed;
    }

    if (isLiveObd && _mafAirFlow > 0 && _speed > 0) {
      _fuelEconomy = (_mafAirFlow * 3600.0) / (14.7 * 750.0 * _speed) * 100.0;
      _fuelEconomy = _fuelEconomy.clamp(0.0, 50.0);
    }
  }

  void resetTrip() {
    _tripDistance = 0.0;
    _tripStartTime = DateTime.now();
    _lastTripUpdateTime = DateTime.now();
    _averageSpeed = 0.0;
    _tripMaxSpeed = 0;
    _speedSampleCount = 0;
    _speedSampleSum = 0.0;
    notifyListeners();
  }

  // =========================================================================
  // PERFORMANCE
  // =========================================================================

  int _peakSpeed = 0;
  int _peakRpm = 0;
  double? _zeroToHundredTime;
  bool _isPerformanceTimerRunning = false;
  DateTime? _performanceTimerStart;

  int get peakSpeed => _peakSpeed;
  int get peakRpm => _peakRpm;
  double? get zeroToHundredTime => _zeroToHundredTime;
  bool get isPerformanceTimerRunning => _isPerformanceTimerRunning;

  double? get performanceTimerElapsed {
    if (_performanceTimerStart == null) return null;
    return DateTime.now().difference(_performanceTimerStart!).inMilliseconds / 1000.0;
  }

  void _updatePerformanceTracking() {
    if (_speed > _peakSpeed) _peakSpeed = _speed;
    if (_rpm > _peakRpm) _peakRpm = _rpm;

    if (_isPerformanceTimerRunning && _performanceTimerStart != null) {
      if (_speed >= 100) {
        _zeroToHundredTime = DateTime.now().difference(_performanceTimerStart!).inMilliseconds / 1000.0;
        _isPerformanceTimerRunning = false;
      }
    }
  }

  void startPerformanceTimer() {
    _zeroToHundredTime = null;
    _isPerformanceTimerRunning = true;
    _performanceTimerStart = DateTime.now();
    notifyListeners();
  }

  void resetPerformance() {
    _peakSpeed = 0;
    _peakRpm = 0;
    _zeroToHundredTime = null;
    _isPerformanceTimerRunning = false;
    _performanceTimerStart = null;
    notifyListeners();
  }

  // =========================================================================
  // DIAGNOSTICS
  // =========================================================================

  List<DtcCode> _dtcCodes = [];
  final List<String> _obdLog = [];

  List<DtcCode> get dtcCodes => _dtcCodes;
  List<String> get obdLog => List<String>.unmodifiable(_obdLog);

  Future<void> refreshDtcCodes() async {
    if (isLiveObd) {
      final List<String> rawCodes = await readRealDtcCodes();
      _dtcCodes = rawCodes.map((String code) {
        final DtcSeverity severity;
        if (code.startsWith('P0') || code.startsWith('P1')) {
          severity = DtcSeverity.error;
        } else if (code.startsWith('P2') || code.startsWith('P3')) {
          severity = DtcSeverity.warning;
        } else {
          severity = DtcSeverity.info;
        }
        return DtcCode(
          code: code,
          description: 'Retrieved from ECU',
          severity: severity,
        );
      }).toList();
      notifyListeners();
    }
  }

  void clearDtcCodes() {
    if (isLiveObd) {
      clearRealDtcCodes().then((_) {
        _dtcCodes = [];
        final String timestamp = DateTime.now().toIso8601String().substring(11, 19);
        _obdLog.add('[$timestamp] > 04\\r  →  DTCs cleared (ECU)');
        notifyListeners();
      });
    }
  }

  // =========================================================================
  // VOICE ASSISTANT
  // =========================================================================

  late final stt.SpeechToText _speechToText;
  late final FlutterTts _flutterTts;

  String _transcription = '';
  String _aiResponse = '';
  bool _isListening = false;
  bool _isProcessing = false;
  bool _isSpeechAvailable = false;

  String get transcription => _transcription;
  String get aiResponse => _aiResponse;
  bool get isListening => _isListening;
  bool get isProcessing => _isProcessing;

  Future<void> _initTts() async {
    await _flutterTts.setLanguage('en-US');
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setPitch(1.0);
  }

  Future<void> startListening() async {
    if (_isListening) return;

    await _flutterTts.stop();

    if (!_isSpeechAvailable) {
      _isSpeechAvailable = await _speechToText.initialize(
        onError: (error) {
          debugPrint('STT error: \${error.errorMsg}');
          _isListening = false;
          notifyListeners();
        },
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            _isListening = false;
            notifyListeners();
            if (_transcription.isNotEmpty && !_isProcessing) {
              _sendToGemini(_transcription);
            }
          }
        },
      );
    }

    if (!_isSpeechAvailable) {
      _aiResponse = 'Speech recognition is not available on this device.';
      notifyListeners();
      return;
    }

    _transcription = '';
    _aiResponse = '';
    _isListening = true;
    notifyListeners();

    await _speechToText.listen(
      onResult: (result) {
        _transcription = result.recognizedWords;
        notifyListeners();
      },
      listenOptions: stt.SpeechListenOptions(
        listenMode: stt.ListenMode.confirmation,
        cancelOnError: true,
      ),
    );
  }

  Future<void> stopListening() async {
    await _speechToText.stop();
    _isListening = false;
    notifyListeners();
  }

  Future<void> _sendToGemini(String userText) async {
    if (_apiKey.isEmpty) {
      _aiResponse = 'Please set your Gemini API Key in Settings first.';
      _speak(_aiResponse);
      return;
    }

    _isProcessing = true;
    _aiResponse = 'Thinking...';
    notifyListeners();

    try {
      final String sysPrompt =
          "You are a helpful car dashboard AI assistant. Keep responses very brief (1-3 sentences). "
          "The car is currently driving at \$_speed \${_speedUnit.label}, RPM is \$_rpm, coolant temp \$_coolantTemp°C. "
          "Provide quick, helpful, safe responses.";

      final Uri url = Uri.parse('\$_kGeminiBaseUrl/\${_selectedModel.apiId}:generateContent?key=\$_apiKey');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'systemInstruction': {
            'parts': [
              {'text': sysPrompt}
            ]
          },
          'contents': [
            {
              'parts': [
                {'text': userText}
              ]
            }
          ],
          'generationConfig': {
            'temperature': 0.7,
            'maxOutputTokens': 150,
          },
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final String text =
            data['candidates'][0]['content']['parts'][0]['text'];
        _aiResponse = text;
        _speak(text);
      } else {
        _aiResponse = 'Failed to connect to AI (Error \${response.statusCode})';
      }
    } catch (e) {
      _aiResponse = 'An error occurred: \$e';
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }

  Future<void> _speak(String text) async {
    // Strip markdown formatting for TTS (rudimentary)
    final cleanText = text.replaceAll(RegExp(r'[*#_]'), '');
    await _flutterTts.speak(cleanText);
  }

  // =========================================================================
  // SETTINGS & PREFERENCES
  // =========================================================================

  String _apiKey = '';
  GeminiModelId _selectedModel = GeminiModelId.gemini25Flash;
  SpeedUnit _speedUnit = SpeedUnit.kmh;
  double _volume = 0.5;

  String get apiKey => _apiKey;
  GeminiModelId get selectedModel => _selectedModel;
  SpeedUnit get speedUnit => _speedUnit;
  double get volume => _volume;

  void setVolume(double value) {
    _volume = value;
    notifyListeners();
  }

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _apiKey = prefs.getString(_kApiKeyPref) ?? '';
    final modelName = prefs.getString(_kModelIdPref);
    if (modelName != null) {
      try {
        _selectedModel = GeminiModelId.fromApiId(modelName);
      } catch (_) {}
    }
    final unitStr = prefs.getString(_kUnitPref);
    if (unitStr != null) {
      _speedUnit = SpeedUnit.values.firstWhere(
        (u) => u.name == unitStr,
        orElse: () => SpeedUnit.kmh,
      );
    }
    notifyListeners();
  }

  Future<void> saveApiKey(String key) async {
    _apiKey = key;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kApiKeyPref, key);
    notifyListeners();
  }

  Future<void> saveSelectedModel(GeminiModelId model) async {
    _selectedModel = model;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kModelIdPref, model.apiId);
    notifyListeners();
  }

  Future<void> saveSpeedUnit(SpeedUnit unit) async {
    _speedUnit = unit;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kUnitPref, unit.name);
    notifyListeners();
  }

  @override
  void dispose() {
    _obdService.dispose();
    _speechToText.cancel();
    _flutterTts.stop();
    super.dispose();
  }
}
