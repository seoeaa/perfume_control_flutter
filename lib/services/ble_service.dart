import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

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
      // The error indicated 'license' is required. Using dynamic cast as seen in previous working version if needed, 
      // but 'device.connect' should work if I provide the named parameter.
      // It seems I am using a version that requires it.
      await (device as dynamic).connect(autoConnect: false, mtu: null, license: License.free); 
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
      log("Services discovered: ${services.length}");
      
      for (var service in services) {
        log("Service: ${service.uuid}");
        for (var char in service.characteristics) {
           log("  Char: ${char.uuid} (Props: ${char.properties})");
           if (char.uuid.toString().toLowerCase().contains("ffe1")) { 
              if (char.properties.write || char.properties.writeWithoutResponse) {
                _writeCharacteristic = char;
                log("  -> Write Char Found (ffe1)");
              }
              if (char.properties.notify || char.properties.indicate) {
                await char.setNotifyValue(true);
                char.lastValueStream.listen((value) {
                   // Convert bytes to hex string for logging
                   final hexStr = value.map((e) => e.toRadixString(16).padLeft(2, '0')).join(' ');
                   _dataController.add(value);
                   log("RX: $hexStr");
                });
                log("  -> Notify Char Found & Enabled (ffe1)");
              }
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
    _connectionController.add(false);
    log("Disconnected");
  }

  Future<void> writeData(List<int> data) async {
    if (_writeCharacteristic != null) {
      await _writeCharacteristic!.write(data, withoutResponse: true);
    }
  }

  void dispose() {
    _connectionController.close();
    _dataController.close();
  }
}
