import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../ble/device_profile.dart';
import '../logic/protocol_handler.dart';

class BleService {
  static const String serviceUuid = "ffe0";

  Future<bool> requestPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();

    return statuses.values.every((status) => status.isGranted);
  }

  static const String writeUuid = "ffe1";
  static const String notifyUuid = "ffe1";

  BluetoothDevice? _connectedDevice;
  BluetoothCharacteristic? _writeCharacteristic;
  BluetoothCharacteristic? _notifyCharacteristic;
  DeviceProfile? _currentProfile;
  List<BluetoothService> _services = [];
  int _sessionId = 0;
  int _connectionAttempts = 0;
  int _txCounter = 0;
  int _rxCounter = 0;
  DateTime? _lastWriteAt;
  static const Duration _minWriteInterval = Duration(milliseconds: 150);

  DeviceProfile? get currentProfile => _currentProfile;

  final _connectionController = StreamController<bool>.broadcast();
  Stream<bool> get connectionStatus => _connectionController.stream;

  final _dataController = StreamController<List<int>>.broadcast();
  Stream<List<int>> get dataStream => _dataController.stream;

  final _logController = StreamController<String>.broadcast();
  Stream<String> get logStream => _logController.stream;

  void log(String message) {
    _logController.add(message);
  }

  String _hex(List<int> data) {
    return data.map((e) => e.toRadixString(16).padLeft(2, '0')).join(' ');
  }

  Future<void> startScan() async {
    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 4));
  }

  Stream<List<ScanResult>> get scanResults => FlutterBluePlus.scanResults;

  Future<void> establishConnection(BluetoothDevice device) async {
    try {
      _connectionAttempts += 1;
      _sessionId = DateTime.now().millisecondsSinceEpoch;
      _txCounter = 0;
      _rxCounter = 0;
      _writeCharacteristic = null;
      _notifyCharacteristic = null;
      _lastWriteAt = null;
      log(
        "Session #$_sessionId | Attempt #$_connectionAttempts | Connecting to ${device.remoteId}...",
      );
      await (device as dynamic).connect(
        autoConnect: false,
        mtu: null,
        license: License.free,
      );
      _connectedDevice = device;
      _connectionController.add(true);
      log("Session #$_sessionId | Connected. Discovering services...");

      if (device.platformName.isNotEmpty) {
        log("Session #$_sessionId | Device Name: ${device.platformName}");
      }

      // Request Mtu
      try {
        await device.requestMtu(512);
        log("Session #$_sessionId | MTU requested: 512");
      } catch (e) {
        log("Session #$_sessionId | MTU request failed: $e");
      }

      List<BluetoothService> services = await device.discoverServices();
      _services = services;
      log("Session #$_sessionId | Services discovered: ${services.length}");

      // Auto-detect profile
      _currentProfile = DeviceProfileManager.findProfile(services);
      var notifySubscribed = false;

      if (_currentProfile != null) {
        log(
          "Session #$_sessionId | Profile detected: ${_currentProfile!.name} (protocol: ${_currentProfile!.protocol})",
        );
      } else {
        log("Session #$_sessionId | No profile detected, using default search");
      }

      // Build a UUID->Characteristic lookup first, then pick channels
      // by profile priority (if detected).
      final charsByUuid = <String, BluetoothCharacteristic>{};
      BluetoothCharacteristic? fallbackWrite;
      BluetoothCharacteristic? fallbackNotify;

      for (var service in services) {
        log("Session #$_sessionId | Service: ${service.uuid}");
        for (var char in service.characteristics) {
          log(
            "Session #$_sessionId |   Char: ${char.uuid} (Props: ${char.properties})",
          );

          final uuid = char.uuid.toString().toLowerCase();
          charsByUuid[uuid] = char;

          if ((char.properties.write || char.properties.writeWithoutResponse) &&
              fallbackWrite == null) {
            fallbackWrite = char;
          }
          if ((char.properties.notify || char.properties.indicate) &&
              fallbackNotify == null) {
            fallbackNotify = char;
          }
        }
      }

      if (_currentProfile != null) {
        for (final writeUuid in _currentProfile!.writeUuids) {
          final candidate = charsByUuid[writeUuid];
          if (candidate != null &&
              (candidate.properties.write ||
                  candidate.properties.writeWithoutResponse)) {
            _writeCharacteristic = candidate;
            log("Session #$_sessionId |   -> Write Char ($writeUuid)");
            break;
          }
        }
        for (final notifyUuid in _currentProfile!.notifyUuids) {
          final candidate = charsByUuid[notifyUuid];
          if (candidate != null &&
              (candidate.properties.notify || candidate.properties.indicate)) {
            _notifyCharacteristic = candidate;
            await _subscribeToNotify(candidate);
            notifySubscribed = true;
            log("Session #$_sessionId |   -> Notify Char ($notifyUuid)");
            break;
          }
        }
      }

      _writeCharacteristic ??= fallbackWrite;
      _notifyCharacteristic ??= fallbackNotify;
      if (_notifyCharacteristic != null && !notifySubscribed) {
        await _subscribeToNotify(_notifyCharacteristic!);
      }

      log(
        "Session #$_sessionId | Active channels | write=${_writeCharacteristic?.uuid} notify=${_notifyCharacteristic?.uuid}",
      );
    } catch (e) {
      log("Session #$_sessionId | Connection Error: $e");
      disconnect();
    }
  }

  Future<void> disconnect() async {
    await _connectedDevice?.disconnect();
    _connectedDevice = null;
    _writeCharacteristic = null;
    _notifyCharacteristic = null;
    _currentProfile = null;
    _connectionController.add(false);
    log("Session #$_sessionId | Disconnected");
  }

  Future<void> _subscribeToNotify(BluetoothCharacteristic char) async {
    if (!char.isNotifying) {
      await char.setNotifyValue(true);
    }
    final uuid = char.uuid.toString().toLowerCase();
    char.lastValueStream.listen((value) {
      _rxCounter += 1;
      final hexStr = _hex(value);
      _dataController.add(value);
      log(
        "Session #$_sessionId | RX #$_rxCounter | from $uuid | len=${value.length} | $hexStr",
      );

      if (_currentProfile == null && value.isNotEmpty) {
        final detected = ProtocolHandler.detectProtocol(value);
        _currentProfile = DeviceProfile(
          name: 'auto',
          writeUuids: [_writeCharacteristic?.uuid.toString().toLowerCase() ?? ''],
          notifyUuids: [uuid],
          protocol: detected,
        );
        log("Session #$_sessionId | Protocol auto-detected: $detected");
      }
    });
  }

  Future<void> _writeWithRateLimit(
    BluetoothCharacteristic characteristic,
    List<int> data,
  ) async {
    final now = DateTime.now();
    if (_lastWriteAt != null) {
      final elapsed = now.difference(_lastWriteAt!);
      if (elapsed < _minWriteInterval) {
        final wait = _minWriteInterval - elapsed;
        log(
          "Session #$_sessionId | TX pacing | waiting ${wait.inMilliseconds}ms before write",
        );
        await Future.delayed(wait);
      }
    }
    final withoutResponse = characteristic.properties.writeWithoutResponse;
    await characteristic.write(data, withoutResponse: withoutResponse);
    _lastWriteAt = DateTime.now();
  }

  Future<void> writeData(List<int> data) async {
    if (_writeCharacteristic != null) {
      _txCounter += 1;
      await _writeWithRateLimit(_writeCharacteristic!, data);
      final withoutResponse =
          _writeCharacteristic!.properties.writeWithoutResponse;
      log(
        "Session #$_sessionId | TX #$_txCounter | len=${data.length} | withoutResponse=$withoutResponse | ${_hex(data)}",
      );
    } else {
      log(
        "Session #$_sessionId | TX skipped: write characteristic is null | payload=${_hex(data)}",
      );
    }
  }

  Future<void> writeDataByProfile(List<int> data) async {
    if (_writeCharacteristic == null || _currentProfile == null) return;

    await _writeWithRateLimit(_writeCharacteristic!, data);
    final withoutResponse =
        _writeCharacteristic!.properties.writeWithoutResponse;
    _txCounter += 1;
    log(
      "Session #$_sessionId | TX #$_txCounter [${_currentProfile!.name}] | len=${data.length} | withoutResponse=$withoutResponse | ${_hex(data)}",
    );
  }

  Future<void> sendStartCommand() async {
    if (_writeCharacteristic == null || _currentProfile == null) {
      log("Cannot send start: no characteristic or profile");
      return;
    }

    Uint8List packet;
    switch (_currentProfile!.protocol) {
      case ProtocolType.a:
        packet = ProtocolHandler.startProtocolC();
        break;
      case ProtocolType.b:
        packet = ProtocolHandler.startProtocolC();
        break;
      case ProtocolType.c:
        packet = ProtocolHandler.startProtocolC();
        break;
    }

    final withoutResponse =
        _writeCharacteristic!.properties.writeWithoutResponse;
    await _writeWithRateLimit(_writeCharacteristic!, packet);
    _txCounter += 1;
    log(
      "Session #$_sessionId | TX #$_txCounter | Start command (${_currentProfile!.protocol}) | ${_hex(packet)}",
    );
  }

  Future<void> sendStopCommand() async {
    if (_writeCharacteristic == null || _currentProfile == null) {
      log("Cannot send stop: no characteristic or profile");
      return;
    }

    Uint8List packet;
    switch (_currentProfile!.protocol) {
      case ProtocolType.a:
        packet = ProtocolHandler.stopProtocolC();
        break;
      case ProtocolType.b:
        packet = ProtocolHandler.stopProtocolC();
        break;
      case ProtocolType.c:
        packet = ProtocolHandler.stopProtocolC();
        break;
    }

    final withoutResponse =
        _writeCharacteristic!.properties.writeWithoutResponse;
    await _writeWithRateLimit(_writeCharacteristic!, packet);
    _txCounter += 1;
    log(
      "Session #$_sessionId | TX #$_txCounter | Stop command (${_currentProfile!.protocol}) | ${_hex(packet)}",
    );
  }

  void dispose() {
    _connectionController.close();
    _dataController.close();
    _logController.close();
  }
}
