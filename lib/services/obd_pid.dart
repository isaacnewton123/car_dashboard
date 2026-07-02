/// Strongly-typed OBD-II PID definitions for the 2021 Daihatsu Sigra R Deluxe.
///
/// Each [ObdPid] knows its Mode 01 command, how many response data bytes
/// to expect, how to parse those bytes into a numeric value, what
/// human-readable unit it represents, and its optimal polling interval.
library;

// ---------------------------------------------------------------------------
// Unit labels
// ---------------------------------------------------------------------------

/// Physical unit for a PID value.
enum ObdUnit {
  rpm('rpm'),
  kmh('km/h'),
  percent('%'),
  celsius('°C'),
  gramsPerSec('g/s'),
  volts('V'),
  kpa('kPa'),
  degrees('°'),
  seconds('s'),
  minutes('min'),
  km('km'),
  ratio('λ'),
  milliamps('mA'),
  none('');

  const ObdUnit(this.label);
  final String label;
}

// ---------------------------------------------------------------------------
// PID definition
// ---------------------------------------------------------------------------

/// A single OBD-II Mode 01 Parameter ID.
class ObdPid {
  const ObdPid({
    required this.id,
    required this.command,
    required this.name,
    required this.unit,
    required this.responseBytes,
    required this.parse,
    this.pollingInterval, // null means pull once on connect
    this.minValue = 0,
    this.maxValue = 100,
  });

  /// Unique identifier matching the hex PID (e.g. `0x0C` for RPM).
  final int id;

  /// The AT command string to send (e.g. `"010C"`).
  final String command;

  /// Human-readable name.
  final String name;

  /// Physical unit.
  final ObdUnit unit;

  /// Number of data bytes expected in the response (after the 41 XX header).
  final int responseBytes;

  /// Parser function: takes the raw data bytes and returns a [double].
  final double Function(List<int> bytes) parse;

  /// Desired polling interval. If null, this PID is only pulled once upon connection.
  final Duration? pollingInterval;

  /// Expected minimum value (for gauge scaling).
  final double minValue;

  /// Expected maximum value (for gauge scaling).
  final double maxValue;
}

// ---------------------------------------------------------------------------
// All supported PIDs for the Sigra ECU
// ---------------------------------------------------------------------------

/// Complete registry of the 35 PIDs available on the Sigra's ECU.
class ObdPids {
  ObdPids._();

  // --- Core Driving ---

  static final ObdPid engineRpm = ObdPid(
    id: 0x0C,
    command: '010C',
    name: 'Engine RPM',
    unit: ObdUnit.rpm,
    responseBytes: 2,
    parse: (List<int> b) => ((b[0] * 256) + b[1]) / 4.0,
    pollingInterval: const Duration(milliseconds: 100),
    maxValue: 8000,
  );

  static final ObdPid vehicleSpeed = ObdPid(
    id: 0x0D,
    command: '010D',
    name: 'Vehicle Speed',
    unit: ObdUnit.kmh,
    responseBytes: 1,
    parse: (List<int> b) => b[0].toDouble(),
    pollingInterval: const Duration(milliseconds: 100),
    maxValue: 220,
  );

  static final ObdPid calculatedLoad = ObdPid(
    id: 0x04,
    command: '0104',
    name: 'Calculated Load',
    unit: ObdUnit.percent,
    responseBytes: 1,
    parse: (List<int> b) => b[0] * 100.0 / 255.0,
    pollingInterval: const Duration(milliseconds: 150),
  );

  static final ObdPid coolantTemp = ObdPid(
    id: 0x05,
    command: '0105',
    name: 'Coolant Temperature',
    unit: ObdUnit.celsius,
    responseBytes: 1,
    parse: (List<int> b) => b[0] - 40.0,
    pollingInterval: const Duration(milliseconds: 2000),
    minValue: -40,
    maxValue: 215,
  );

  // --- Fuel Trim ---

  static final ObdPid shortTermFuelTrimB1 = ObdPid(
    id: 0x06,
    command: '0106',
    name: 'Short-Term Fuel Trim B1',
    unit: ObdUnit.percent,
    responseBytes: 1,
    parse: (List<int> b) => (b[0] - 128) * 100.0 / 128.0,
    pollingInterval: const Duration(milliseconds: 2000),
    minValue: -100,
  );

  static final ObdPid longTermFuelTrimB1 = ObdPid(
    id: 0x07,
    command: '0107',
    name: 'Long-Term Fuel Trim B1',
    unit: ObdUnit.percent,
    responseBytes: 1,
    parse: (List<int> b) => (b[0] - 128) * 100.0 / 128.0,
    pollingInterval: const Duration(milliseconds: 2000),
    minValue: -100,
  );

  // --- Ignition & Intake ---

  static final ObdPid ignitionTiming = ObdPid(
    id: 0x0E,
    command: '010E',
    name: 'Ignition Timing',
    unit: ObdUnit.degrees,
    responseBytes: 1,
    parse: (List<int> b) => b[0] / 2.0 - 64.0,
    pollingInterval: const Duration(milliseconds: 1000),
    minValue: -64,
    maxValue: 63.5,
  );

  static final ObdPid intakeAirTemp = ObdPid(
    id: 0x0F,
    command: '010F',
    name: 'Intake Air Temperature',
    unit: ObdUnit.celsius,
    responseBytes: 1,
    parse: (List<int> b) => b[0] - 40.0,
    pollingInterval: const Duration(milliseconds: 2000),
    minValue: -40,
    maxValue: 215,
  );

  static final ObdPid mafAirFlowRate = ObdPid(
    id: 0x10,
    command: '0110',
    name: 'MAF Air Flow Rate',
    unit: ObdUnit.gramsPerSec,
    responseBytes: 2,
    parse: (List<int> b) => ((b[0] * 256) + b[1]) / 100.0,
    pollingInterval: const Duration(milliseconds: 1000),
    maxValue: 655.35,
  );

  // --- Throttle ---

  static final ObdPid throttlePosition = ObdPid(
    id: 0x11,
    command: '0111',
    name: 'Throttle Position',
    unit: ObdUnit.percent,
    responseBytes: 1,
    parse: (List<int> b) => b[0] * 100.0 / 255.0,
    pollingInterval: const Duration(milliseconds: 150),
  );

  // --- O2 Sensors (Narrow-band) ---

  static final ObdPid o2SensorB1S2Voltage = ObdPid(
    id: 0x15,
    command: '0115',
    name: 'O2 Sensor B1S2 Voltage',
    unit: ObdUnit.volts,
    responseBytes: 2,
    parse: (List<int> b) => b[0] / 200.0,
    pollingInterval: const Duration(milliseconds: 2000),
    maxValue: 1.275,
  );

  static final ObdPid o2SensorB1S2FuelTrim = ObdPid(
    id: 0x15,
    command: '0115',
    name: 'O2 Sensor B1S2 Fuel Trim',
    unit: ObdUnit.percent,
    responseBytes: 2,
    parse: (List<int> b) => (b[1] - 128) * 100.0 / 128.0,
    pollingInterval: const Duration(milliseconds: 2000),
    minValue: -100,
  );

  // --- OBD Status ---

  static final ObdPid obdCompliance = ObdPid(
    id: 0x1C,
    command: '011C',
    name: 'OBD Compliance',
    unit: ObdUnit.none,
    responseBytes: 1,
    parse: (List<int> b) => b[0].toDouble(),
    pollingInterval: null, // One pull when connected
    maxValue: 255,
  );

  static final ObdPid timeSinceEngineStart = ObdPid(
    id: 0x1F,
    command: '011F',
    name: 'Time Since Engine Start',
    unit: ObdUnit.seconds,
    responseBytes: 2,
    parse: (List<int> b) => ((b[0] * 256) + b[1]).toDouble(),
    pollingInterval: const Duration(milliseconds: 5000),
    maxValue: 65535,
  );

  static final ObdPid distanceWithMil = ObdPid(
    id: 0x21,
    command: '0121',
    name: 'Distance with MIL',
    unit: ObdUnit.km,
    responseBytes: 2,
    parse: (List<int> b) => ((b[0] * 256) + b[1]).toDouble(),
    pollingInterval: const Duration(milliseconds: 10000),
    maxValue: 65535,
  );

  // --- O2 Wide-Range Sensors ---

  static final ObdPid o2SensorB1S1WrVoltage = ObdPid(
    id: 0x24,
    command: '0124',
    name: 'O2 Sensor B1S1 WR Voltage',
    unit: ObdUnit.volts,
    responseBytes: 4,
    parse: (List<int> b) => ((b[2] * 256) + b[3]) / 8192.0,
    pollingInterval: const Duration(milliseconds: 2000),
    maxValue: 8.0,
  );

  static final ObdPid lambdaO2B1S1Wr = ObdPid(
    id: 0x24,
    command: '0124',
    name: 'Lambda O2 B1S1 WR',
    unit: ObdUnit.ratio,
    responseBytes: 4,
    parse: (List<int> b) => ((b[0] * 256) + b[1]) / 32768.0,
    pollingInterval: const Duration(milliseconds: 2000),
    maxValue: 2.0,
  );

  // --- EVAP & Resets ---

  static final ObdPid commandedEvapPurge = ObdPid(
    id: 0x2E,
    command: '012E',
    name: 'Commanded Evap Purge',
    unit: ObdUnit.percent,
    responseBytes: 1,
    parse: (List<int> b) => b[0] * 100.0 / 255.0,
    pollingInterval: const Duration(milliseconds: 5000),
  );

  static final ObdPid warmupsSinceEcuReset = ObdPid(
    id: 0x30,
    command: '0130',
    name: 'Warm-ups Since ECU Reset',
    unit: ObdUnit.none,
    responseBytes: 1,
    parse: (List<int> b) => b[0].toDouble(),
    pollingInterval: null,
    maxValue: 255,
  );

  static final ObdPid distanceSinceEcuReset = ObdPid(
    id: 0x31,
    command: '0131',
    name: 'Distance Since ECU Reset',
    unit: ObdUnit.km,
    responseBytes: 2,
    parse: (List<int> b) => ((b[0] * 256) + b[1]).toDouble(),
    pollingInterval: const Duration(milliseconds: 10000),
    maxValue: 65535,
  );

  // --- Barometric ---

  static final ObdPid barometricPressure = ObdPid(
    id: 0x33,
    command: '0133',
    name: 'Barometric Pressure',
    unit: ObdUnit.kpa,
    responseBytes: 1,
    parse: (List<int> b) => b[0].toDouble(),
    pollingInterval: const Duration(milliseconds: 10000),
    maxValue: 255,
  );

  // --- O2 Wide-Range Current ---

  static final ObdPid o2SensorB1S1CurrentWr = ObdPid(
    id: 0x34,
    command: '0134',
    name: 'O2 Sensor B1S1 Current WR',
    unit: ObdUnit.milliamps,
    responseBytes: 4,
    parse: (List<int> b) => ((b[2] * 256) + b[3]) / 256.0 - 128.0,
    pollingInterval: const Duration(milliseconds: 2000),
    minValue: -128,
    maxValue: 128,
  );

  static final ObdPid lambdaO2B1S1CurrentWr = ObdPid(
    id: 0x34,
    command: '0134',
    name: 'Lambda O2 B1S1',
    unit: ObdUnit.ratio,
    responseBytes: 4,
    parse: (List<int> b) => ((b[0] * 256) + b[1]) / 32768.0,
    pollingInterval: const Duration(milliseconds: 2000),
    maxValue: 2.0,
  );

  // --- Catalytic Converter Temps ---

  static final ObdPid catTempB1S1 = ObdPid(
    id: 0x3C,
    command: '013C',
    name: 'CAT Temp B1S1',
    unit: ObdUnit.celsius,
    responseBytes: 2,
    parse: (List<int> b) => ((b[0] * 256) + b[1]) / 10.0 - 40.0,
    pollingInterval: const Duration(milliseconds: 5000),
    minValue: -40,
    maxValue: 6513.5,
  );

  static final ObdPid catTempB1S2 = ObdPid(
    id: 0x3E,
    command: '013E',
    name: 'CAT Temp B1S2',
    unit: ObdUnit.celsius,
    responseBytes: 2,
    parse: (List<int> b) => ((b[0] * 256) + b[1]) / 10.0 - 40.0,
    pollingInterval: const Duration(milliseconds: 5000),
    minValue: -40,
    maxValue: 6513.5,
  );

  // --- ECU Voltage ---

  static final ObdPid ecuVoltage = ObdPid(
    id: 0x42,
    command: '0142',
    name: 'ECU Voltage',
    unit: ObdUnit.volts,
    responseBytes: 2,
    parse: (List<int> b) => ((b[0] * 256) + b[1]) / 1000.0,
    pollingInterval: const Duration(milliseconds: 5000),
    maxValue: 65.535,
  );

  // --- Engine Load & Equivalence ---

  static final ObdPid absoluteEngineLoad = ObdPid(
    id: 0x43,
    command: '0143',
    name: 'Absolute Engine Load',
    unit: ObdUnit.percent,
    responseBytes: 2,
    parse: (List<int> b) => ((b[0] * 256) + b[1]) * 100.0 / 255.0,
    pollingInterval: const Duration(milliseconds: 150),
    maxValue: 25700,
  );

  static final ObdPid commandedEquivRatio = ObdPid(
    id: 0x44,
    command: '0144',
    name: 'Commanded Equivalence Ratio',
    unit: ObdUnit.ratio,
    responseBytes: 2,
    parse: (List<int> b) => ((b[0] * 256) + b[1]) / 32768.0,
    pollingInterval: const Duration(milliseconds: 2000),
    maxValue: 2.0,
  );

  // --- Throttle Variants ---

  static final ObdPid relativeThrottlePos = ObdPid(
    id: 0x45,
    command: '0145',
    name: 'Relative Throttle Position',
    unit: ObdUnit.percent,
    responseBytes: 1,
    parse: (List<int> b) => b[0] * 100.0 / 255.0,
    pollingInterval: const Duration(milliseconds: 150),
  );

  static final ObdPid absThrottlePosB = ObdPid(
    id: 0x47,
    command: '0147',
    name: 'Abs Throttle Position B',
    unit: ObdUnit.percent,
    responseBytes: 1,
    parse: (List<int> b) => b[0] * 100.0 / 255.0,
    pollingInterval: const Duration(milliseconds: 150),
  );

  static final ObdPid absThrottlePosD = ObdPid(
    id: 0x49,
    command: '0149',
    name: 'Abs Throttle Position D',
    unit: ObdUnit.percent,
    responseBytes: 1,
    parse: (List<int> b) => b[0] * 100.0 / 255.0,
    pollingInterval: const Duration(milliseconds: 150),
  );

  static final ObdPid absThrottlePosE = ObdPid(
    id: 0x4A,
    command: '014A',
    name: 'Abs Throttle Position E',
    unit: ObdUnit.percent,
    responseBytes: 1,
    parse: (List<int> b) => b[0] * 100.0 / 255.0,
    pollingInterval: const Duration(milliseconds: 150),
  );

  static final ObdPid throttleActuatorCtrl = ObdPid(
    id: 0x4C,
    command: '014C',
    name: 'Throttle Actuator Control',
    unit: ObdUnit.percent,
    responseBytes: 1,
    parse: (List<int> b) => b[0] * 100.0 / 255.0,
    pollingInterval: const Duration(milliseconds: 150),
  );

  // --- MIL Runtime & DTC Time ---

  static final ObdPid engineRunTimeWithMil = ObdPid(
    id: 0x4D,
    command: '014D',
    name: 'Engine Run Time with MIL',
    unit: ObdUnit.minutes,
    responseBytes: 2,
    parse: (List<int> b) => ((b[0] * 256) + b[1]).toDouble(),
    pollingInterval: null,
    maxValue: 65535,
  );

  static final ObdPid timeSinceDtcCleared = ObdPid(
    id: 0x4E,
    command: '014E',
    name: 'Time Since DTC Cleared',
    unit: ObdUnit.minutes,
    responseBytes: 2,
    parse: (List<int> b) => ((b[0] * 256) + b[1]).toDouble(),
    pollingInterval: const Duration(milliseconds: 10000),
    maxValue: 65535,
  );

  // ---------------------------------------------------------------------------
  // Lists
  // ---------------------------------------------------------------------------

  static final List<ObdPid> all = [
    engineRpm,
    vehicleSpeed,
    calculatedLoad,
    coolantTemp,
    shortTermFuelTrimB1,
    longTermFuelTrimB1,
    ignitionTiming,
    intakeAirTemp,
    mafAirFlowRate,
    throttlePosition,
    o2SensorB1S2Voltage,
    o2SensorB1S2FuelTrim,
    obdCompliance,
    timeSinceEngineStart,
    distanceWithMil,
    o2SensorB1S1WrVoltage,
    lambdaO2B1S1Wr,
    commandedEvapPurge,
    warmupsSinceEcuReset,
    distanceSinceEcuReset,
    barometricPressure,
    o2SensorB1S1CurrentWr,
    lambdaO2B1S1CurrentWr,
    catTempB1S1,
    catTempB1S2,
    ecuVoltage,
    absoluteEngineLoad,
    commandedEquivRatio,
    relativeThrottlePos,
    absThrottlePosB,
    absThrottlePosD,
    absThrottlePosE,
    throttleActuatorCtrl,
    engineRunTimeWithMil,
    timeSinceDtcCleared,
  ];

  static final List<ObdPid> oneTimePulls =
      all.where((p) => p.pollingInterval == null).toList();

  static final List<ObdPid> periodicPulls =
      all.where((p) => p.pollingInterval != null).toList();

  /// Critical PIDs polled every cycle for real-time responsiveness (~100-200ms).
  static final List<ObdPid> criticalPids = <ObdPid>[engineRpm, vehicleSpeed];

  /// Normal periodic PIDs, deduplicated by command string.
  ///
  /// Only one representative PID per unique command is included.
  /// When polled, all sibling PIDs sharing the same command are parsed
  /// from the single response by [ObdService._pollPidGroup].
  static final List<ObdPid> normalPeriodicUniqueCommands = () {
    final Set<String> seenCommands = <String>{};
    final Set<String> criticalCommands =
        criticalPids.map((ObdPid p) => p.command).toSet();
    return periodicPulls
        .where((ObdPid p) => !criticalCommands.contains(p.command))
        .where((ObdPid p) => seenCommands.add(p.command))
        .toList();
  }();
}
