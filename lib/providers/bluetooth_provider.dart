import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../services/ble_service.dart';
import '../logic/protocol_handler.dart';
import '../ble/device_profile.dart';

class BluetoothProvider with ChangeNotifier {
  final BleService _bleService = BleService();
  bool _isConnected = false;
  bool _isScanning = false;
  List<ScanResult> _discoveredDevices = [];
  bool _isPowerOn = true;
  bool _ionEnabled = false;
  bool _fragranceEnabled = true;

  // Independent levels (Intensity) for A, B, C (0: Off, 1: Light, 2: Fresh, 3: Rich)
  final Map<int, int> _intensities = {0: 1, 1: 0, 2: 0};

  // Fluid Levels (0-100%)
  final Map<int, int> _fluidLevels = {0: 0, 1: 0, 2: 0};

  // Debug Logs
  List<String> _logs = [];
  DeviceStatus? _lastParsedStatus;

  bool get isConnected => _isConnected;
  bool get isScanning => _isScanning;
  List<ScanResult> get discoveredDevices => _discoveredDevices;
  bool get isPowerOn => _isPowerOn;
  bool get ionEnabled => _ionEnabled;
  bool get fragranceEnabled => _fragranceEnabled;
  int getIntensity(int channel) => _intensities[channel] ?? 0;
  int getFluidLevel(int channel) => _fluidLevels[channel] ?? 100;
  List<String> get logs => _logs;

  void addToLog(String message) {
    String timestamp = DateTime.now()
        .toIso8601String()
        .split('T')
        .last
        .split('.')
        .first;
    _logs.add("[$timestamp] $message");
    notifyListeners();
  }

  void clearLogs() {
    _logs.clear();
    notifyListeners();
  }



  String _hex(List<int> bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');

  void _logStatusDiff(DeviceStatus current) {
    final previous = _lastParsedStatus;
    if (previous == null) {
      _lastParsedStatus = current;
      return;
    }

    final currentMap = current.toMap();
    final previousMap = previous.toMap();
    final changedFields = <String, Map<String, dynamic>>{};

    currentMap.forEach((key, value) {
      if (previousMap[key] != value) {
        changedFields[key] = {'was': previousMap[key], 'now': value};
      }
    });

    final changedBytes = <int>[];
    if (current.rawBytes.length == previous.rawBytes.length) {
      for (int i = 0; i < current.rawBytes.length; i++) {
        if (current.rawBytes[i] != previous.rawBytes[i]) {
          changedBytes.add(i);
        }
      }
    }

    if (changedFields.isNotEmpty || changedBytes.isNotEmpty) {
      addToLog('━━━ STATUS DIFF ━━━');

      if (changedFields.isNotEmpty) {
        changedFields.forEach((field, values) {
          addToLog('  field [$field]: ${values['was']} -> ${values['now']}');
        });
      } else {
        addToLog('  field diff: none');
      }

      if (changedBytes.isNotEmpty) {
        for (final i in changedBytes) {
          final prevHex = previous.rawBytes[i].toRadixString(16).padLeft(2, '0');
          final currHex = current.rawBytes[i].toRadixString(16).padLeft(2, '0');
          addToLog('  byte  [$i]: 0x$prevHex -> 0x$currHex');
        }
      } else if (current.rawBytes.length != previous.rawBytes.length) {
        addToLog(
          '  byte diff: skipped (length ${previous.rawBytes.length} -> ${current.rawBytes.length})',
        );
      } else {
        addToLog('  byte diff: none');
      }

      if (changedBytes.length > changedFields.length && changedBytes.isNotEmpty) {
        addToLog(
          '  ⚠ unknown byte changes: $changedBytes (possible undiscovered fields)',
        );
        addToLog('  WAS: ${_hex(previous.rawBytes)}');
        addToLog('  NOW: ${_hex(current.rawBytes)}');
      }

      addToLog('━━━━━━━━━━━━━━━━━━━');
    }

    _lastParsedStatus = current;
  }
  BluetoothProvider() {
    _bleService.connectionStatus.listen((status) {
      _isConnected = status;
      addToLog(status ? "Connected successfully" : "Disconnected");
      if (status) {
        _isScanning = false;
        _discoveredDevices = [];

        // Use detected profile to determine protocol
        final profile = _bleService.currentProfile;
        if (profile != null) {
          addToLog(
            "Using profile: ${profile.name} (protocol: ${profile.protocol})",
          );

          // Send appropriate protocol-specific commands
          Future.delayed(const Duration(seconds: 1), () {
            switch (profile.protocol) {
              case ProtocolType.a:
                syncTime();
                break;
              case ProtocolType.b:
                _bleService.writeData(ProtocolHandler.requestStatusB());
                break;
              case ProtocolType.c:
                _bleService.sendStartCommand();
                break;
            }
          });
        } else {
          // Fallback: try protocol A
          Future.delayed(const Duration(seconds: 1), () => syncTime());
        }
      } else {
        _lastParsedStatus = null;
      }
      notifyListeners();
    });

    _bleService.scanResults.listen((results) {
      _discoveredDevices = results;
      notifyListeners();
    });

    _bleService.logStream.listen((message) {
      addToLog(message);
    });

    _bleService.dataStream.listen((data) {
      if (data.isEmpty) return;

      // Basic parsing logic
      try {
        if (data[0] == 0xA5) {
          final status = ProtocolHandler.parseStatusB(data);
          if (status != null) {
            addToLog("Parsed: $status");
            _logStatusDiff(status);
            _fluidLevels[0] = status.levelA;
            _fluidLevels[1] = status.levelB;
            _fluidLevels[2] = status.levelC;
            _isPowerOn = status.powerOn;
            // TODO: Ion/Fragrance flags if we find them
            notifyListeners();
          }
        } else if (data[0] == 0x7E) {
          // Protocol A
          final cmd = ProtocolHandler.parseProtocolA(data);
          if (cmd != null) {
            addToLog("RX Cmd: $cmd");
            if (cmd.param1 == 5) _intensities[0] = cmd.param2;
            if (cmd.param1 == 6) _intensities[1] = cmd.param2;
            if (cmd.param1 == 7) _intensities[2] = cmd.param2;

            if (cmd.param1 == 2) {
              // Ion or Fragrance
              // We need to confirm which is which.
              // Based on setFragranceSwitchA: data: [0x02, 0x01, on ? 1 : 2]
              // Based on setIonSwitchA: data: [0x02, 0x02, on ? 1 : 2]
              // But wait, parseProtocolA returns param1 as data[3] and param2 as data[4]
              // In setFragranceSwitchA: 0x7E 06 02 01 [1/2]
              // In setIonSwitchA: 0x7E 06 02 02 [1/2]
              // So if param1 (data[3]) is 1 -> Fragrance
              // If param1 (data[3]) is 2 -> Ion

              // However, earlier logs showed:
              // RX: 7e 06 02 07 03 -> Channel C (7), Level 3
              // This fits: param1=7, param2=3.

              // Let's refine the logic:
            }

            if (cmd.param1 == 1) {
              // Fragrance Master Switch
              _fragranceEnabled = (cmd.param2 == 1);
            }
            if (cmd.param1 == 2) {
              // Ion Switch
              _ionEnabled = (cmd.param2 == 1);
            }

            notifyListeners();
          } else {
            addToLog(
              "RX Protocol A: ${data.map((e) => e.toRadixString(16)).join(' ')}",
            );
          }
        }
      } catch (e) {
        addToLog("Parsing error: $e");
      }
    });
  }

  Future<void> scanAndConnect() async {
    addToLog("Starting scan...");
    bool hasPermission = await _bleService.requestPermissions();
    if (!hasPermission) {
      addToLog("Permission denied");
      return;
    }

    _isScanning = true;
    _discoveredDevices = [];
    notifyListeners();

    await _bleService.startScan();

    // Auto-stop scanning after 10 seconds
    Future.delayed(const Duration(seconds: 10), () {
      if (_isScanning) {
        _isScanning = false;
        FlutterBluePlus.stopScan();
        notifyListeners();
      }
    });
  }

  Future<void> connectToDevice(BluetoothDevice device) async {
    addToLog(
      "UI Action: connectToDevice(name=${device.platformName.isNotEmpty ? device.platformName : 'unknown'}, id=${device.remoteId})",
    );
    _isScanning = false;
    FlutterBluePlus.stopScan();
    notifyListeners();
    await _bleService.establishConnection(device);
  }

  void togglePower() {
    _isPowerOn = !_isPowerOn;
    final profile = _bleService.currentProfile;
    addToLog(
      "UI Action: togglePower -> $_isPowerOn (profile=${profile?.name}, protocol=${profile?.protocol})",
    );

    if (profile != null) {
      switch (profile.protocol) {
        case ProtocolType.a:
          _bleService.writeData(
            ProtocolHandler.setFragranceSwitchA(_isPowerOn),
          );
          break;
        case ProtocolType.b:
          _bleService.writeData(
            ProtocolHandler.setFragranceSwitchA(_isPowerOn),
          );
          break;
        case ProtocolType.c:
          if (_isPowerOn) {
            _bleService.sendStartCommand();
          } else {
            _bleService.sendStopCommand();
          }
          break;
      }
    } else {
      _bleService.writeData(ProtocolHandler.setFragranceSwitchA(_isPowerOn));
    }
    notifyListeners();
  }

  void toggleIon() {
    _ionEnabled = !_ionEnabled;
    final profile = _bleService.currentProfile;
    addToLog(
      "UI Action: toggleIon -> $_ionEnabled (profile=${profile?.name}, protocol=${profile?.protocol})",
    );

    if (profile != null &&
        (profile.protocol == ProtocolType.a ||
            profile.protocol == ProtocolType.b)) {
      _bleService.writeData(ProtocolHandler.setIonSwitchA(_ionEnabled));
    }
    notifyListeners();
  }

  void toggleFragrance() {
    _fragranceEnabled = !_fragranceEnabled;
    final profile = _bleService.currentProfile;
    addToLog(
      "UI Action: toggleFragrance -> $_fragranceEnabled (profile=${profile?.name}, protocol=${profile?.protocol})",
    );

    if (profile != null &&
        (profile.protocol == ProtocolType.a ||
            profile.protocol == ProtocolType.b)) {
      _bleService.writeData(
        ProtocolHandler.setFragranceSwitchA(_fragranceEnabled),
      );
    }
    notifyListeners();
  }

  void setChannelIntensity(int channel, int level) {
    _intensities[channel] = level;
    final profile = _bleService.currentProfile;
    addToLog(
      "UI Action: setChannelIntensity(channel=$channel, level=$level, profile=${profile?.name}, protocol=${profile?.protocol})",
    );

    if (profile != null) {
      switch (profile.protocol) {
        case ProtocolType.a:
          _bleService.writeData(ProtocolHandler.setIntensityA(channel, level));
          break;
        case ProtocolType.b:
          _bleService.writeData(ProtocolHandler.setIntensityB(channel, level));
          break;
        case ProtocolType.c:
          _bleService.writeData(ProtocolHandler.setIntensityC(channel, level));
          break;
      }
    } else {
      _bleService.writeData(ProtocolHandler.setIntensityA(channel, level));
    }
    notifyListeners();
  }

  void syncTime() {
    addToLog("UI Action: syncTime()");
    _bleService.writeData(ProtocolHandler.syncTimeA());
  }

  @override
  void dispose() {
    _bleService.dispose();
    super.dispose();
  }
}
