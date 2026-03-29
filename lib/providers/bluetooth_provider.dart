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
  bool _isManualOverride = false;
  ProtocolType? _manualProtocol;

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
  ProtocolType? get manualProtocol => _manualProtocol;

  void addToLog(String message) {
    String timestamp = DateTime.now()
        .toIso8601String()
        .split('T')
        .last
        .split('.')
        .first;
    final logMsg = "[$timestamp] $message";
    debugPrint("UI: $logMsg");
    _logs.add(logMsg);
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

        // Use manual protocol if set, otherwise use detected profile
        final profile = _bleService.currentProfile;
        final protocol = _manualProtocol ?? profile?.protocol;

        if (_manualProtocol != null) {
          _bleService.forceProtocol(_manualProtocol!);
          addToLog("Manual protocol OVERRIDE: $_manualProtocol");
        }

        if (protocol != null) {
          addToLog(
            "Using protocol: $protocol (Source: ${_manualProtocol != null ? 'Manual' : 'Auto'})",
          );

          // Send appropriate protocol-specific commands
          Future.delayed(const Duration(seconds: 1), () {
            switch (protocol) {
              case ProtocolType.a:
                syncTime();
                break;
              case ProtocolType.b:
                _bleService.writeData(ProtocolHandler.requestStatusB());
                break;
              case ProtocolType.c:
                _bleService.sendStartCommand();
                syncTime(); // Also sync time for C if supported
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

      final profile = _bleService.currentProfile;
      
      try {
        // If profile is Protocol B or we see patterns of B
        if (profile?.protocol == ProtocolType.b || data[0] == 0xA5 || (data.length > 1 && data[0] == 0x05 && data[1] == 0x05)) {
          final status = ProtocolHandler.parseStatusB(data);
          if (status != null) {
            _logStatusDiff(status);
            _fluidLevels[0] = status.levelA;
            _fluidLevels[1] = status.levelB;
            _fluidLevels[2] = status.levelC;
            
            if (!_isManualOverride) {
              _isPowerOn = status.powerOn;
              // If status levels are small (0-3), they might be intensities
              if (status.levelA <= 3) _intensities[0] = status.levelA;
              if (status.levelB <= 3) _intensities[1] = status.levelB;
              if (status.levelC <= 3) _intensities[2] = status.levelC;
            }
            notifyListeners();
          }
        } 
        
        // Protocol A check (must have 7E header)
        if (data[0] == 0x7E) {
          final cmd = ProtocolHandler.parseProtocolA(data);
          if (cmd != null) {
            addToLog("RX Cmd: $cmd");
            if (cmd.param1 == 5) _intensities[0] = cmd.param2;
            if (cmd.param1 == 6) _intensities[1] = cmd.param2;
            if (cmd.param1 == 7) _intensities[2] = cmd.param2;

            if (cmd.param1 == 1) {
              _fragranceEnabled = (cmd.param2 == 1);
            }
            if (cmd.param1 == 2) {
              _ionEnabled = (cmd.param2 == 1);
            }
            notifyListeners();
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
    _isManualOverride = true;
    Future.delayed(const Duration(seconds: 2), () => _isManualOverride = false);
    
    final profile = _bleService.currentProfile;
    final protocol = _manualProtocol ?? profile?.protocol;

    addToLog(
      "UI Action: togglePower -> $_isPowerOn (protocol=$protocol)",
    );

    if (protocol != null) {
      switch (protocol) {
        case ProtocolType.a:
          _bleService.writeData(
            ProtocolHandler.setFragranceSwitchA(_isPowerOn),
          );
          break;
        case ProtocolType.b:
          _bleService.writeData(
            ProtocolHandler.setPowerB(_isPowerOn),
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
    _isManualOverride = true;
    Future.delayed(const Duration(seconds: 2), () => _isManualOverride = false);

    final profile = _bleService.currentProfile;
    final protocol = _manualProtocol ?? profile?.protocol;

    addToLog(
      "UI Action: toggleIon -> $_ionEnabled (protocol=$protocol)",
    );

    if (protocol != null) {
      if (protocol == ProtocolType.a) {
        _bleService.writeData(ProtocolHandler.setIonSwitchA(_ionEnabled));
      } else if (protocol == ProtocolType.b) {
        _bleService.writeData(
          ProtocolHandler.buildProtocolB(data: [0x05, _ionEnabled ? 1 : 0]),
        );
      }
    }
    notifyListeners();
  }

  void toggleFragrance() {
    _fragranceEnabled = !_fragranceEnabled;
    final profile = _bleService.currentProfile;
    final protocol = _manualProtocol ?? profile?.protocol;

    addToLog(
      "UI Action: toggleFragrance -> $_fragranceEnabled (protocol=$protocol)",
    );

    if (protocol != null) {
      if (protocol == ProtocolType.a) {
        _bleService.writeData(
          ProtocolHandler.setFragranceSwitchA(_fragranceEnabled),
        );
      } else if (protocol == ProtocolType.b) {
        _bleService.writeData(ProtocolHandler.setPowerB(_fragranceEnabled));
      }
    }
    notifyListeners();
  }

  void setChannelIntensity(int channel, int level) {
    _intensities[channel] = level;
    final profile = _bleService.currentProfile;
    final protocol = _manualProtocol ?? profile?.protocol;

    addToLog(
      "UI Action: setChannelIntensity(channel=$channel, level=$level, protocol=$protocol)",
    );

    if (protocol != null) {
      switch (protocol) {
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
    final protocol = _manualProtocol ?? _bleService.currentProfile?.protocol ?? ProtocolType.a;
    addToLog("UI Action: syncTime(protocol=$protocol)");
    _bleService.writeData(ProtocolHandler.syncTime(protocol));
  }

  void setManualProtocol(ProtocolType? type) {
    _manualProtocol = type;
    if (_isConnected && type != null) {
      _bleService.forceProtocol(type);
      addToLog("Manual protocol applied: $type");
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _bleService.dispose();
    super.dispose();
  }
}
