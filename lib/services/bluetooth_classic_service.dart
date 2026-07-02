/// Bluetooth Classic (RFCOMM/SPP) service using native platform channels.
///
/// Communicates with [BluetoothClassicHandler] on the Android side
/// via [MethodChannel] for commands and [EventChannel] for incoming data.
///
/// No third-party Bluetooth library is used.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

// ---------------------------------------------------------------------------
// Models
// ---------------------------------------------------------------------------

/// Represents a paired Bluetooth device.
class BluetoothDeviceInfo {
  const BluetoothDeviceInfo({
    required this.name,
    required this.address,
  });

  /// Human-readable device name (may be empty for unnamed devices).
  final String name;

  /// MAC address (e.g. `"00:11:22:33:AA:BB"`).
  final String address;

  /// Display-friendly name — falls back to [address] when [name] is empty.
  String get displayName => name.isNotEmpty ? name : address;
}

// ---------------------------------------------------------------------------
// Service
// ---------------------------------------------------------------------------

/// Low-level Bluetooth Classic (RFCOMM) service backed by native Android code.
///
/// Usage:
/// ```dart
/// final bt = BluetoothClassicService();
/// final devices = await bt.getBondedDevices();
/// await bt.connect(devices.first.address);
/// bt.inputStream?.listen((data) => print(data));
/// await bt.write('ATZ\r');
/// await bt.disconnect();
/// ```
class BluetoothClassicService {
  static const MethodChannel _methodChannel =
      MethodChannel('car_dashboard/bluetooth_classic');
  static const EventChannel _eventChannel =
      EventChannel('car_dashboard/bluetooth_classic/input');

  StreamSubscription<Uint8List>? _inputSubscription;
  Stream<Uint8List>? _broadcastStream;

  /// Whether the native socket is currently connected.
  Future<bool> getIsConnected() async {
    final bool result =
        await _methodChannel.invokeMethod<bool>('isConnected') ?? false;
    return result;
  }

  /// Returns the list of Bluetooth devices paired in Android Settings.
  Future<List<BluetoothDeviceInfo>> getBondedDevices() async {
    final List<dynamic>? result =
        await _methodChannel.invokeMethod<List<dynamic>>('getBondedDevices');

    if (result == null) return <BluetoothDeviceInfo>[];

    return result.map((dynamic item) {
      final Map<Object?, Object?> map = item as Map<Object?, Object?>;
      return BluetoothDeviceInfo(
        name: (map['name'] as String?) ?? '',
        address: (map['address'] as String?) ?? '',
      );
    }).toList();
  }

  /// Open an insecure RFCOMM socket to [address] (SPP UUID).
  ///
  /// After connecting, [inputStream] becomes available for reading data.
  /// Throws [PlatformException] on failure.
  Future<bool> connect(String address) async {
    final bool result = await _methodChannel
            .invokeMethod<bool>('connect', <String, String>{'address': address}) ??
        false;

    if (result) {
      _broadcastStream = _eventChannel
          .receiveBroadcastStream()
          .map((dynamic event) => event as Uint8List);
    }

    return result;
  }

  /// The raw byte stream from the connected device.
  ///
  /// Returns `null` when not connected.
  Stream<Uint8List>? get inputStream => _broadcastStream;

  /// Subscribe to the input stream with [onData], [onDone], and [onError].
  ///
  /// Returns the subscription, which the caller should cancel on disconnect.
  StreamSubscription<Uint8List>? listen({
    required void Function(Uint8List data) onData,
    void Function()? onDone,
    void Function(Object error)? onError,
  }) {
    _inputSubscription?.cancel();
    _inputSubscription = _broadcastStream?.listen(
      onData,
      onDone: onDone,
      onError: (Object error, StackTrace _) => onError?.call(error),
    );
    return _inputSubscription;
  }

  /// Write a UTF-8 string to the connected device.
  Future<void> writeString(String data) async {
    await _methodChannel.invokeMethod<bool>(
      'write',
      <String, dynamic>{'data': Uint8List.fromList(utf8.encode(data))},
    );
  }

  /// Write raw bytes to the connected device.
  Future<void> writeBytes(Uint8List data) async {
    await _methodChannel.invokeMethod<bool>(
      'write',
      <String, dynamic>{'data': data},
    );
  }

  /// Close the RFCOMM socket and stop the input reader thread.
  Future<void> disconnect() async {
    await _inputSubscription?.cancel();
    _inputSubscription = null;
    _broadcastStream = null;
    await _methodChannel.invokeMethod<bool>('disconnect');
  }

  /// Release all resources.
  void dispose() {
    _inputSubscription?.cancel();
    _inputSubscription = null;
    _broadcastStream = null;
  }
}
