import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
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
  BluetoothCharacteristic? _mirrorWriteCharacteristic;
  BluetoothCharacteristic? _notifyCharacteristic;
  DeviceProfile? _currentProfile;
  List<BluetoothService> _services = [];
  int _sessionId = 0;
  int _connectionAttempts = 0;
  int _txCounter = 0;
  int _rxCounter = 0;
  DateTime? _lastWriteAt;
  static const Duration _minWriteInterval = Duration(milliseconds: 150);
  StreamSubscription<BluetoothConnectionState>? _deviceStateSub;
  List<int>? _lastRxValue;

  BluetoothDevice? get connectedDevice => _connectedDevice;
  BluetoothDevice? get currentDevice => _connectedDevice;
  DeviceProfile? get currentProfile => _currentProfile;

  final _connectionController = StreamController<bool>.broadcast();
  Stream<bool> get connectionStatus => _connectionController.stream;

  final _dataController = StreamController<List<int>>.broadcast();
  Stream<bool> get dataStreamIsActive => Stream.value(true); // Placeholder
  Stream<List<int>> get dataStream => _dataController.stream;

  final _logController = StreamController<String>.broadcast();
  Stream<String> get logStream => _logController.stream;

  void log(String message) {
    debugPrint("BLE: $message");
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
      _mirrorWriteCharacteristic = null;
      _notifyCharacteristic = null;
      _lastWriteAt = null;
      await _deviceStateSub?.cancel();
      _deviceStateSub = null;
      log(
        "Session #$_sessionId | Attempt #$_connectionAttempts | Connecting to ${device.remoteId}...",
      );
      await (device as dynamic).connect(
        autoConnect: false,
        mtu: null,
        license: License.free,
      );
      _connectedDevice = device;
      _deviceStateSub = device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          _handleDisconnectedByDevice();
        }
      });
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
      _currentProfile = DeviceProfileManager.findProfile(device, _services);
      if (_currentProfile != null) {
        log("Session #$_sessionId | Profile matched: ${_currentProfile!.name} [Protocol ${_currentProfile!.protocol}]");
      } else {
        log("Session #$_sessionId | WARNING: No matching profile found. Using fallback.");
      }

      var notifySubscribed = false;

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
        if (_currentProfile!.name == 'classic_ffe' && _writeCharacteristic != null) {
          for (final writeUuid in _currentProfile!.writeUuids) {
            final candidate = charsByUuid[writeUuid];
            if (candidate != null &&
                candidate.uuid != _writeCharacteristic!.uuid &&
                (candidate.properties.write ||
                    candidate.properties.writeWithoutResponse)) {
              _mirrorWriteCharacteristic = candidate;
              log(
                "Session #$_sessionId |   -> Mirror Write Char ($writeUuid)",
              );
              break;
            }
          }
        }
        for (final notifyUuid in _currentProfile!.notifyUuids) {
          final candidate = charsByUuid[notifyUuid];
          if (candidate != null &&
              (candidate.properties.notify || candidate.properties.indicate)) {
            _notifyCharacteristic = candidate;
            await _subscribeToNotify(candidate);
            notifySubscribed = true;
            log("Session #$_sessionId |   -> Main Notify Char ($notifyUuid)");
            break;
          }
        }
        
        // Strategy: also listen to ALL other notify chars just in case (for unknown devices)
        for (var char in charsByUuid.values) {
           if ((char.properties.notify || char.properties.indicate) && char.uuid != _notifyCharacteristic?.uuid) {
             await _subscribeToNotify(char);
             log("Session #$_sessionId |   -> Extra Notify Char (${char.uuid})");
           }
        }
      }

      _writeCharacteristic ??= fallbackWrite;
      _notifyCharacteristic ??= fallbackNotify;
      if (_notifyCharacteristic != null && !notifySubscribed) {
        await _subscribeToNotify(_notifyCharacteristic!);
      }

      // FINAL SAFETY DELAY
      await Future.delayed(const Duration(milliseconds: 300));

      log(
        "Session #$_sessionId | Active channels | write=${_writeCharacteristic?.uuid} mirror=${_mirrorWriteCharacteristic?.uuid} notify=${_notifyCharacteristic?.uuid}",
      );

      // ONLY NOW notify listeners that we are fully connected and ready
      _connectionController.add(true);
    } catch (e) {
      log("Session #$_sessionId | Connection Error: $e");
      disconnect();
    }
  }

  Future<void> disconnect() async {
    await _deviceStateSub?.cancel();
    _deviceStateSub = null;
    await _connectedDevice?.disconnect();
    _handleDisconnectedByDevice();
  }

  void _handleDisconnectedByDevice() {
    final wasConnected = _connectedDevice != null || _isChannelActive();
    _connectedDevice = null;
    _writeCharacteristic = null;
    _mirrorWriteCharacteristic = null;
    _notifyCharacteristic = null;
    _currentProfile = null;
    _lastWriteAt = null;
    if (wasConnected) {
      _connectionController.add(false);
      log("Session #$_sessionId | Disconnected");
    }
  }

  bool _isChannelActive() {
    return _writeCharacteristic != null || _notifyCharacteristic != null;
  }

  Future<void> _subscribeToNotify(BluetoothCharacteristic char) async {
    if (!char.isNotifying) {
      await char.setNotifyValue(true);
    }
    final uuid = char.uuid.toString().toLowerCase();
    char.lastValueStream.listen((value) {
      _rxCounter += 1;
      
      bool changed = _lastRxValue == null || !listEquals(_lastRxValue, value);
      _lastRxValue = List<int>.from(value);

      // ALWAYS add to controller so UI stays up to date
      _dataController.add(value);

      if (changed) {
        final hexStr = _hex(value);
        String? asciiStr;
        try {
          if (value.every((b) => (b >= 32 && b <= 126) || b == 10 || b == 13)) {
            asciiStr = String.fromCharCodes(value).replaceAll('\r', '\\r').replaceAll('\n', '\\n');
          }
        } catch (_) {}

        log(
          "Session #$_sessionId | RX #$_rxCounter | from $uuid | len=${value.length} | $hexStr ${asciiStr != null ? ' | ASCII: \"$asciiStr\"' : ''}",
        );
      }

      if (value.isNotEmpty) {
        final detected = ProtocolHandler.detectProtocol(value);
        if (detected != null) {
          if (_currentProfile != null && _currentProfile!.protocol != detected) {
            log(
              "Session #$_sessionId | Protocol MISMATCH: Profile was ${_currentProfile!.protocol}, Data is $detected. UPGRADING.",
            );
            _currentProfile = DeviceProfile(
              name: "${_currentProfile!.name}_$detected",
              writeUuids: _currentProfile!.writeUuids,
              notifyUuids: _currentProfile!.notifyUuids,
              protocol: detected,
            );
          } else if (_currentProfile == null) {
            _currentProfile = DeviceProfile(
              name: 'auto',
              writeUuids: [
                _writeCharacteristic?.uuid.toString().toLowerCase() ?? '',
              ],
              notifyUuids: [uuid],
              protocol: detected,
            );
            log("Session #$_sessionId | Protocol auto-detected: $detected");
          }
        }
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
        if (wait.inMilliseconds > 10) {
          await Future.delayed(wait);
        }
      }
    }
    final withoutResponse = characteristic.properties.writeWithoutResponse;
    await characteristic.write(data, withoutResponse: withoutResponse);
    _lastWriteAt = DateTime.now();
  }

  Future<void> _writeToCharacteristic(
    BluetoothCharacteristic characteristic,
    List<int> data, {
    required String label,
  }) async {
    try {
      await _writeWithRateLimit(characteristic, data);
      final withoutResponse = characteristic.properties.writeWithoutResponse;
      log(
        "Session #$_sessionId | $label | len=${data.length} | withoutResponse=$withoutResponse | ${_hex(data)}",
      );
    } catch (e) {
      log("Session #$_sessionId | $label ERROR: $e");
    }
  }

  Future<void> writeData(List<int> data) async {
    if (_writeCharacteristic == null) {
      log(
        "Session #$_sessionId | TX skipped: write characteristic is null | payload=${_hex(data)}",
      );
      return;
    }

    _txCounter += 1;
    final txId = _txCounter;
    await _writeToCharacteristic(
      _writeCharacteristic!,
      data,
      label: "TX #$txId",
    );

    if (_mirrorWriteCharacteristic != null) {
      await _writeToCharacteristic(
        _mirrorWriteCharacteristic!,
        data,
        label: "TX #$txId mirror",
      );
    }
  }

  Future<void> writeDataByProfile(List<int> data) async {
    if (_writeCharacteristic == null || _currentProfile == null) return;

    _txCounter += 1;
    final txId = _txCounter;
    await _writeToCharacteristic(
      _writeCharacteristic!,
      data,
      label: "TX #$txId [${_currentProfile!.name}]",
    );

    if (_mirrorWriteCharacteristic != null) {
      await _writeToCharacteristic(
        _mirrorWriteCharacteristic!,
        data,
        label: "TX #$txId mirror [${_currentProfile!.name}]",
      );
    }
  }

  Future<void> sendStartCommand() async {
    if (_writeCharacteristic == null || _currentProfile == null) return;

    Uint8List packet;
    switch (_currentProfile!.protocol) {
      case ProtocolType.a:
        packet = ProtocolHandler.startProtocolC();
        break;
      case ProtocolType.b:
        packet = ProtocolHandler.startProtocolC(); // Placeholder for B
        break;
      case ProtocolType.c:
        packet = ProtocolHandler.startProtocolC();
        break;
    }

    _txCounter += 1;
    final txId = _txCounter;
    await _writeToCharacteristic(_writeCharacteristic!, packet, label: "TX #$txId | Start");
    if (_mirrorWriteCharacteristic != null) {
      await _writeToCharacteristic(_mirrorWriteCharacteristic!, packet, label: "TX #$txId mirror | Start");
    }
  }

  Future<void> sendStopCommand() async {
    if (_writeCharacteristic == null || _currentProfile == null) return;

    Uint8List packet;
    switch (_currentProfile!.protocol) {
      case ProtocolType.a:
        packet = ProtocolHandler.stopProtocolC();
        break;
      case ProtocolType.b:
        packet = ProtocolHandler.stopProtocolC(); // Placeholder
        break;
      case ProtocolType.c:
        packet = ProtocolHandler.stopProtocolC();
        break;
    }

    _txCounter += 1;
    final txId = _txCounter;
    await _writeToCharacteristic(_writeCharacteristic!, packet, label: "TX #$txId | Stop");
    if (_mirrorWriteCharacteristic != null) {
      await _writeToCharacteristic(_mirrorWriteCharacteristic!, packet, label: "TX #$txId mirror | Stop");
    }
  }

  void dispose() {
    _deviceStateSub?.cancel();
    _connectionController.close();
    _dataController.close();
    _logController.close();
  }

  void forceProtocol(ProtocolType type) {
    if (_currentProfile?.protocol == type) return;

    log("Session #$_sessionId | FORCING Protocol Type: $type");
    
    // Try to find a matching profile for this specific protocol
    final forcedProfile = DeviceProfileManager.getProfileForProtocol(type);
    
    if (forcedProfile != null) {
      _currentProfile = DeviceProfile(
        name: "forced_${forcedProfile.name}",
        writeUuids: _currentProfile?.writeUuids ?? forcedProfile.writeUuids,
        notifyUuids: _currentProfile?.notifyUuids ?? forcedProfile.notifyUuids,
        protocol: type,
      );
    } else {
       _currentProfile = DeviceProfile(
        name: "forced_raw",
        writeUuids: _currentProfile?.writeUuids ?? [],
        notifyUuids: _currentProfile?.notifyUuids ?? [],
        protocol: type,
      );
    }
  }
}
