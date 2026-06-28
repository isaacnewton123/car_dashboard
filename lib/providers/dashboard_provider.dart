import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../models/dtc_code.dart';
import '../models/gemini_model.dart';

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const Duration _kMockTickInterval = Duration(milliseconds: 500);
const String _kApiKeyPref = 'gemini_api_key';
const String _kModelIdPref = 'gemini_model_id';
const String _kUnitPref = 'speed_unit'; // "kmh" | "mph"
const String _kGeminiBaseUrl =
    'https://generativelanguage.googleapis.com/v1beta/models';

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
///
/// Manages:
/// - Simulated OBD-II telemetry (speed, RPM, temps, etc.)
/// - Trip computer accumulation
/// - Performance tracking (0–100, peaks)
/// - Voice assistant (STT → Gemini → TTS)
/// - Diagnostics (mock DTCs, OBD log)
/// - User settings (API key, model, units)
class DashboardProvider extends ChangeNotifier {
  DashboardProvider() {
    _speechToText = stt.SpeechToText();
    _flutterTts = FlutterTts();
    _initTts();
    loadSettings();
    startMockDataSimulation();
  }

  // =========================================================================
  // OBD-II MOCK DATA — Primary Telemetry
  // =========================================================================

  int _speed = 0;
  int _rpm = 800;
  int _coolantTemp = 70;
  bool _isConnected = true;

  // Extended gauges
  int _engineLoad = 0;
  int _intakeAirTemp = 25;
  double _batteryVoltage = 12.6;
  int _fuelLevel = 78;
  int _gear = 0; // 0 = N, 1–6
  int _throttlePosition = 0;
  int _mapPressure = 30;
  double _fuelRate = 1.5;
  double _fuelTrim = 0.0;
  double _o2SensorVoltage = 0.45;

  int get speed => _speed;
  int get rpm => _rpm;
  int get coolantTemp => _coolantTemp;
  bool get isConnected => _isConnected;
  int get engineLoad => _engineLoad;
  int get intakeAirTemp => _intakeAirTemp;
  double get batteryVoltage => _batteryVoltage;
  int get fuelLevel => _fuelLevel;
  int get gear => _gear;
  int get throttlePosition => _throttlePosition;
  int get mapPressure => _mapPressure;
  double get fuelRate => _fuelRate;
  double get fuelTrim => _fuelTrim;
  double get o2SensorVoltage => _o2SensorVoltage;

  /// Returns speed converted to the user's preferred unit.
  int get displaySpeed {
    if (_speedUnit == SpeedUnit.mph) {
      return (_speed * 0.621371).round();
    }
    return _speed;
  }

  Timer? _mockTimer;
  double _mockPhase = 0.0;
  int _mockTick = 0;

  void startMockDataSimulation() {
    _isConnected = true;
    _tripStartTime = DateTime.now();
    _mockTimer?.cancel();
    _mockTimer = Timer.periodic(_kMockTickInterval, (_) {
      _mockPhase += 0.03;
      _mockTick++;

      // Speed: smooth sine oscillation 0–180 km/h
      final double speedWave = (sin(_mockPhase) + 1) / 2;
      _speed = (speedWave * 180).round();

      // RPM: correlated with speed, 800 idle to ~6500
      _rpm = 800 + ((_speed / 180) * 5700).round();

      // Gear: derived from speed ranges
      if (_speed < 10) {
        _gear = 0;
      } else if (_speed < 30) {
        _gear = 1;
      } else if (_speed < 55) {
        _gear = 2;
      } else if (_speed < 85) {
        _gear = 3;
      } else if (_speed < 120) {
        _gear = 4;
      } else if (_speed < 155) {
        _gear = 5;
      } else {
        _gear = 6;
      }

      // Coolant: slow climb 70→90, with spikes to 97 every ~60 ticks
      final int baseTemp = 70 + min((_mockTick ~/ 10), 20);
      final bool spiking = (_mockTick % 60) > 50;
      _coolantTemp = spiking ? min(baseTemp + 12, 100) : baseTemp;

      // Engine load: sine wave 10–85%
      _engineLoad = (10 + (sin(_mockPhase * 1.3) + 1) / 2 * 75).round();

      // Intake air temp: slow oscillation 20–50°C
      _intakeAirTemp =
          (25 + sin(_mockPhase * 0.5) * 15).round().clamp(15, 55);

      // Throttle Position: 0-100% depending on engine load & speed
      _throttlePosition = ((_engineLoad * 1.1) + (sin(_mockPhase * 2) * 10)).round().clamp(0, 100);

      // MAP: 30 kPa (idle) to 110 kPa
      _mapPressure = 30 + ((_throttlePosition / 100) * 80).round();

      // Battery voltage: mostly stable 13.5–14.4V
      _batteryVoltage =
          13.8 + sin(_mockPhase * 0.7) * 0.6;

      // Fuel Efficiency Metrics
      // Fuel rate: Idle is ~1.2, WOT is ~15.0 L/h. Correlates with throttle.
      _fuelRate = 1.2 + ((_throttlePosition / 100) * 13.8) + (sin(_mockPhase * 3) * 0.5);
      _fuelRate = _fuelRate.clamp(0.0, 20.0);
      
      // Fuel Trim: -10.0 to +10.0%
      _fuelTrim = sin(_mockPhase * 0.8) * 6.0 + (sin(_mockPhase * 1.5) * 2.0);

      // O2 Sensor: Rapid switching between 0.1 and 0.9V
      _o2SensorVoltage = 0.5 + sin(_mockPhase * 8) * 0.4;
      _o2SensorVoltage = _o2SensorVoltage.clamp(0.0, 1.0);

      // Fuel level: very slow decrease
      _fuelLevel = max(5, 78 - (_mockTick ~/ 40));

      // Trip computer accumulation
      _updateTripData();

      // Performance tracking
      _updatePerformanceTracking();

      // OBD log (every 10 ticks)
      if (_mockTick % 10 == 0) {
        _addObdLogEntry();
      }

      notifyListeners();
    });
    notifyListeners();
  }

  void stopMockDataSimulation() {
    _mockTimer?.cancel();
    _mockTimer = null;
    _isConnected = false;
    notifyListeners();
  }

  // =========================================================================
  // TRIP COMPUTER
  // =========================================================================

  double _tripDistance = 0.0; // km
  DateTime _tripStartTime = DateTime.now();
  double _averageSpeed = 0.0;
  double _fuelEconomy = 8.5; // L/100km mock
  int _tripMaxSpeed = 0;
  int _speedSampleCount = 0;
  double _speedSampleSum = 0.0;

  double get tripDistance => _tripDistance;
  Duration get tripTime => DateTime.now().difference(_tripStartTime);
  double get averageSpeed => _averageSpeed;
  double get fuelEconomy => _fuelEconomy;
  int get tripMaxSpeed => _tripMaxSpeed;

  void _updateTripData() {
    // Distance: speed (km/h) × tick interval (0.5s) converted to km
    final double distanceIncrement =
        _speed / 3600.0 * (_kMockTickInterval.inMilliseconds / 1000.0);
    _tripDistance += distanceIncrement;

    // Average speed
    if (_speed > 0) {
      _speedSampleCount++;
      _speedSampleSum += _speed;
      _averageSpeed = _speedSampleSum / _speedSampleCount;
    }

    // Max speed
    if (_speed > _tripMaxSpeed) {
      _tripMaxSpeed = _speed;
    }

    // Fuel economy: mock slight variation
    _fuelEconomy = 7.5 + sin(_mockPhase * 0.3) * 2.0;
  }

  void resetTrip() {
    _tripDistance = 0.0;
    _tripStartTime = DateTime.now();
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
  double _mockGForce = 0.0;

  int get peakSpeed => _peakSpeed;
  int get peakRpm => _peakRpm;
  double? get zeroToHundredTime => _zeroToHundredTime;
  bool get isPerformanceTimerRunning => _isPerformanceTimerRunning;
  double get mockGForce => _mockGForce;

  /// Current elapsed time on the 0-100 timer (live).
  double? get performanceTimerElapsed {
    if (_performanceTimerStart == null) return null;
    return DateTime.now()
            .difference(_performanceTimerStart!)
            .inMilliseconds /
        1000.0;
  }

  void _updatePerformanceTracking() {
    if (_speed > _peakSpeed) _peakSpeed = _speed;
    if (_rpm > _peakRpm) _peakRpm = _rpm;

    // Mock G-force: based on speed change rate
    _mockGForce = sin(_mockPhase * 2) * 0.4;

    // 0-100 timer
    if (_isPerformanceTimerRunning && _performanceTimerStart != null) {
      if (_speed >= 100) {
        _zeroToHundredTime = DateTime.now()
                .difference(_performanceTimerStart!)
                .inMilliseconds /
            1000.0;
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

  final List<DtcCode> _dtcCodes = const [
    DtcCode(
      code: 'P0301',
      description: 'Cylinder 1 Misfire Detected',
      severity: DtcSeverity.error,
    ),
    DtcCode(
      code: 'P0420',
      description: 'Catalyst System Efficiency Below Threshold',
      severity: DtcSeverity.warning,
    ),
    DtcCode(
      code: 'C0035',
      description: 'Left Front Wheel Speed Circuit',
      severity: DtcSeverity.info,
    ),
    DtcCode(
      code: 'P0171',
      description: 'System Too Lean (Bank 1)',
      severity: DtcSeverity.warning,
    ),
  ];

  final List<String> _obdLog = [];

  List<DtcCode> get dtcCodes => _dtcCodes;
  List<String> get obdLog => List<String>.unmodifiable(_obdLog);

  void _addObdLogEntry() {
    final String timestamp =
        DateTime.now().toIso8601String().substring(11, 19);
    final List<String> commands = [
      '> 010D\\r  →  41 0D ${_speed.toRadixString(16).toUpperCase().padLeft(2, "0")}',
      '> 010C\\r  →  41 0C ${(_rpm * 4 ~/ 256).toRadixString(16).toUpperCase().padLeft(2, "0")} ${(_rpm * 4 % 256).toRadixString(16).toUpperCase().padLeft(2, "0")}',
      '> 0105\\r  →  41 05 ${(_coolantTemp + 40).toRadixString(16).toUpperCase().padLeft(2, "0")}',
    ];
    for (final String cmd in commands) {
      _obdLog.add('[$timestamp] $cmd');
    }
    // Keep last 60 entries
    if (_obdLog.length > 60) {
      _obdLog.removeRange(0, _obdLog.length - 60);
    }
  }

  void clearDtcCodes() {
    // Mock: just log it
    final String timestamp =
        DateTime.now().toIso8601String().substring(11, 19);
    _obdLog.add('[$timestamp] > 04\\r  →  DTCs cleared (mock)');
    notifyListeners();
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
          debugPrint('STT error: ${error.errorMsg}');
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
      _aiResponse = 'Please set your Gemini API key in Settings.';
      notifyListeners();
      return;
    }

    _isProcessing = true;
    notifyListeners();

    final String contextPrompt = 'You are an in-car AI assistant. '
        'The driver\'s name is Isaac Newton, and the car is a Sigra R Deluxe. '
        'Current vehicle telemetry — '
        'Speed: $_speed km/h, RPM: $_rpm, '
        'Coolant: $_coolantTemp°C, Engine Load: $_engineLoad%, '
        'Battery: ${_batteryVoltage.toStringAsFixed(1)}V. '
        'The driver asked: "$userText". '
        'Respond concisely and helpfully, and feel free to address the driver by name.';

    final Uri uri = Uri.parse(
      '$_kGeminiBaseUrl/${_selectedModel.apiId}:generateContent?key=$_apiKey',
    );

    try {
      final http.Response response = await http.post(
        uri,
        headers: <String, String>{'Content-Type': 'application/json'},
        body: jsonEncode(<String, Object>{
          'contents': <Map<String, Object>>[
            <String, Object>{
              'parts': <Map<String, String>>[
                <String, String>{'text': contextPrompt},
              ],
            },
          ],
        }),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data =
            jsonDecode(response.body) as Map<String, dynamic>;
        final List<dynamic> candidates =
            data['candidates'] as List<dynamic>? ?? <dynamic>[];
        if (candidates.isNotEmpty) {
          final Map<String, dynamic> firstCandidate =
              candidates[0] as Map<String, dynamic>;
          final Map<String, dynamic> content =
              firstCandidate['content'] as Map<String, dynamic>;
          final List<dynamic> parts =
              content['parts'] as List<dynamic>? ?? <dynamic>[];
          if (parts.isNotEmpty) {
            final Map<String, dynamic> firstPart =
                parts[0] as Map<String, dynamic>;
            _aiResponse = firstPart['text'] as String? ?? 'No response text.';
          } else {
            _aiResponse = 'Empty response from Gemini.';
          }
        } else {
          _aiResponse = 'No candidates in Gemini response.';
        }
      } else {
        _aiResponse =
            'Gemini API error ${response.statusCode}: ${response.body}';
      }
    } catch (e) {
      _aiResponse = 'Network error: $e';
    }

    _isProcessing = false;
    notifyListeners();

    if (_aiResponse.isNotEmpty) {
      await _flutterTts.speak(_aiResponse);
    }
  }

  // =========================================================================
  // SETTINGS
  // =========================================================================

  String _apiKey = '';
  GeminiModelId _selectedModel = GeminiModelId.gemini25Flash;
  SpeedUnit _speedUnit = SpeedUnit.kmh;
  int _volume = 50;

  String get apiKey => _apiKey;
  GeminiModelId get selectedModel => _selectedModel;
  SpeedUnit get speedUnit => _speedUnit;
  int get volume => _volume;

  void setVolume(int val) {
    _volume = val.clamp(0, 100);
    notifyListeners();
  }

  void increaseVolume() {
    if (_volume < 100) {
      _volume += 10;
      notifyListeners();
    }
  }

  void decreaseVolume() {
    if (_volume > 0) {
      _volume -= 10;
      notifyListeners();
    }
  }

  Future<void> loadSettings() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    _apiKey = prefs.getString(_kApiKeyPref) ?? '';
    final String storedModelId =
        prefs.getString(_kModelIdPref) ?? GeminiModelId.gemini25Flash.apiId;
    _selectedModel = GeminiModelId.fromApiId(storedModelId);
    final String storedUnit = prefs.getString(_kUnitPref) ?? 'kmh';
    _speedUnit = storedUnit == 'mph' ? SpeedUnit.mph : SpeedUnit.kmh;
    notifyListeners();
  }

  Future<void> saveApiKey(String key) async {
    _apiKey = key.trim();
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kApiKeyPref, _apiKey);
    notifyListeners();
  }

  Future<void> saveSelectedModel(GeminiModelId model) async {
    _selectedModel = model;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kModelIdPref, model.apiId);
    notifyListeners();
  }

  Future<void> saveSpeedUnit(SpeedUnit unit) async {
    _speedUnit = unit;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kUnitPref, unit == SpeedUnit.mph ? 'mph' : 'kmh');
    notifyListeners();
  }

  // =========================================================================
  // LIFECYCLE
  // =========================================================================

  @override
  void dispose() {
    _mockTimer?.cancel();
    _speechToText.cancel();
    _flutterTts.stop();
    super.dispose();
  }
}
