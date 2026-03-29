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

  Future<void> startScan() async {
    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 4));
  }

  Stream<List<ScanResult>> get scanResults => FlutterBluePlus.scanResults;

  Future<void> establishConnection(BluetoothDevice device) async {
    try {
      log("Connecting to ${device.remoteId}...");
      await (device as dynamic).connect(
        autoConnect: false,
        mtu: null,
        license: License.free,
      );
      _connectedDevice = device;
      _connectionController.add(true);
      log("Connected. Discovering services...");

      if (device.platformName.isNotEmpty) {
        log("Device Name: ${device.platformName}");
      }

      // Request Mtu
      try {
        await device.requestMtu(512);
        log("MTU requested");
      } catch (e) {
        log("MTU request failed: $e");
      }

      List<BluetoothService> services = await device.discoverServices();
      _services = services;
      log("Services discovered: ${services.length}");

      // Auto-detect profile
      _currentProfile = DeviceProfileManager.findProfile(services);
      if (_currentProfile != null) {
        log(
          "Profile detected: ${_currentProfile!.name} (protocol: ${_currentProfile!.protocol})",
        );
      } else {
        log("No profile detected, using default search");
      }

      // Known UUIDs
      final knownWriteUuids = DeviceProfileManager.getAllWriteUuids();
      final knownNotifyUuids = DeviceProfileManager.getAllNotifyUuids();

      for (var service in services) {
        log("Service: ${service.uuid}");
        for (var char in service.characteristics) {
          log("  Char: ${char.uuid} (Props: ${char.properties})");

          final uuid = char.uuid.toString().toLowerCase();

          // Write: ffe1, fff2, 00112433...
          if ((char.properties.write || char.properties.writeWithoutResponse) &&
              (knownWriteUuids.contains(uuid) ||
                  _writeCharacteristic == null)) {
            _writeCharacteristic = char;
            log("  -> Write Char ($uuid)");
          }

          // Notify: ONLY from known notify UUIDs (ffe2, fff1, 00112333...)
          // Skip ffe1 even if it has notify=true (it's used for write!)
          if ((char.properties.notify || char.properties.indicate) &&
              knownNotifyUuids.contains(uuid) &&
              _notifyCharacteristic == null) {
            _notifyCharacteristic = char;
            await char.setNotifyValue(true);
            char.lastValueStream.listen((value) {
              final hexStr = value
                  .map((e) => e.toRadixString(16).padLeft(2, '0'))
                  .join(' ');
              _dataController.add(value);
              log("RX: $hexStr");

              if (_currentProfile == null && value.isNotEmpty) {
                final detected = ProtocolHandler.detectProtocol(value);
                _currentProfile = DeviceProfile(
                  name: 'auto',
                  writeUuids: [
                    _writeCharacteristic?.uuid.toString().toLowerCase() ?? '',
                  ],
                  notifyUuids: [uuid],
                  protocol: detected,
                );
                log("Protocol auto-detected: $detected");
              }
            });
            log("  -> Notify Char ($uuid)");
          }
        }
      }
    } catch (e) {
      log("Connection Error: $e");
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
    log("Disconnected");
  }

  Future<void> writeData(List<int> data) async {
    if (_writeCharacteristic != null) {
      final withoutResponse =
          _writeCharacteristic!.properties.writeWithoutResponse;
      await _writeCharacteristic!.write(data, withoutResponse: withoutResponse);
      log(
        "TX: ${data.map((e) => e.toRadixString(16).padLeft(2, '0')).join(' ')}",
      );
    }
  }

  Future<void> writeDataByProfile(List<int> data) async {
    if (_writeCharacteristic == null || _currentProfile == null) return;

    final withoutResponse =
        _writeCharacteristic!.properties.writeWithoutResponse;
    await _writeCharacteristic!.write(data, withoutResponse: withoutResponse);
    log(
      "TX [${_currentProfile!.name}]: ${data.map((e) => e.toRadixString(16).padLeft(2, '0')).join(' ')}",
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
    await _writeCharacteristic!.write(packet, withoutResponse: withoutResponse);
    log(
      "TX Start: ${packet.map((e) => e.toRadixString(16).padLeft(2, '0')).join(' ')}",
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
    await _writeCharacteristic!.write(packet, withoutResponse: withoutResponse);
    log(
      "TX Stop: ${packet.map((e) => e.toRadixString(16).padLeft(2, '0')).join(' ')}",
    );
  }

  void dispose() {
    _connectionController.close();
    _dataController.close();
    _logController.close();
  }
}
