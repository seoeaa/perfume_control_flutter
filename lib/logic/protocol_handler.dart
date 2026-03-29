import 'dart:typed_data';
import '../ble/device_profile.dart';

class ProtocolHandler {
  // Protocol A Constants
  static const int headerA = 0x7E;
  static const int footerA = 0xEF;
  static const List<int> markerA = [0xFF, 0xFF, 0x00];

  // Protocol B Constants
  static const int headerB = 0x55;
  static const int footerB = 0xAA;
  static const int cmdIdB = 0x20;

  /// Builds a packet for Protocol A
  /// Format: [0x7E] [Cmd] [Data...] [0xFF] [0xFF] [0x00] [0xEF]
  static Uint8List buildProtocolA({required int command, List<int>? data}) {
    List<int> packet = [];
    packet.add(headerA);
    packet.add(command);
    if (data != null) {
      packet.addAll(data);
    }
    packet.addAll(markerA);
    packet.add(footerA);
    return Uint8List.fromList(packet);
  }

  /// Builds a packet for Protocol B
  /// Format: [0x55] [L+1] [CmdID] [Data...] [Checksum] [0xAA]
  static Uint8List buildProtocolB({
    int cmdId = cmdIdB,
    required List<int> data,
  }) {
    List<int> packet = [];
    int lenPlusOne = data.length + 1;

    packet.add(headerB);
    packet.add(lenPlusOne);
    packet.add(cmdId);
    packet.addAll(data);

    // Checksum: (~(sum(CmdID + Data))) & 0xFF
    int sum = cmdId;
    for (int byte in data) {
      sum += byte;
    }
    int checksum = (~sum) & 0xFF;

    packet.add(checksum);
    packet.add(footerB);

    return Uint8List.fromList(packet);
  }

  // Predefined Commands

  /// Sync Time for Protocol A
  static Uint8List syncTimeA() {
    final now = DateTime.now();
    return buildProtocolA(
      command: 0x07,
      data: [now.year % 100, now.month, now.day],
    );
  }

  /// Set Level for Protocol A
  /// channel: 0=A, 1=B, 2=C mapped to parameters 5, 6, 7
  static Uint8List setIntensityA(int channel, int level) {
    return buildProtocolA(command: 0x06, data: [0x02, channel + 5, level]);
  }

  /// Ion Switch (Protocol A) - ON=1, OFF=2
  static Uint8List setIonSwitchA(bool on) {
    return buildProtocolA(command: 0x06, data: [0x02, 0x02, on ? 1 : 2]);
  }

  /// Fragrance Switch (Protocol A) - ON=1, OFF=2
  static Uint8List setFragranceSwitchA(bool on) {
    return buildProtocolA(command: 0x06, data: [0x02, 0x01, on ? 1 : 2]);
  }

  /// Scent Type (Protocol A) - A=1, B=2, C=3
  static Uint8List setScentTypeA(int index) {
    return buildProtocolA(command: 0x06, data: [0x02, 0x04, index + 1]);
  }

  /// Status Request for Protocol B
  static Uint8List requestStatusB() {
    return buildProtocolB(data: [0x06, 0x01]);
  }

  /// Set Level for Protocol B
  static Uint8List setIntensityB(int channel, int level) {
    return buildProtocolB(data: [0x03, channel, level]);
  }

  /// Parses Protocol B Status Packet (starting with 0xA5)
  static DeviceStatus? parseStatusB(List<int> data) {
    // a5 00 13 60 25 28 05 05 25 19 64 64 80 0e 0d 05 05 00 0c 10 fa be 11
    //       index: 0  1  2  3  4   5   6   7   8   9  10  11  12
    if (data.length < 13 || data[0] != 0xA5) return null;

    try {
      // Correct mapping from log analysis:
      // data[4] = channel A level (0x25 = 37)
      // data[5] = channel B level (0x28 = 40)
      // data[10] = channel C level (0x64 = 100)
      // data[12] = flags (0x80 = Power On)

      int levelA = data[4];
      int levelB = data[5];
      int levelC = data[10];
      int flags = data[12];

      bool powerOn = (flags & 0x80) != 0;

      return DeviceStatus(
        levelA: levelA,
        levelB: levelB,
        levelC: levelC,
        flags: flags,
        powerOn: powerOn,
        rawBytes: List<int>.from(data),
      );
    } catch (e) {
      return null;
    }
  }

  /// Parses Protocol A Packet (starting with 0x7E)
  static ProtocolACommand? parseProtocolA(List<int> data) {
    if (data.length < 5 || data[0] != 0x7E) return null;

    try {
      int len = data[1];
      int cmd = data[2];

      if (cmd == 0x02) {
        int param1 = data[3];
        int param2 = data[4];

        return ProtocolACommand(command: cmd, param1: param1, param2: param2);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // ========== Protocol C: AA 55 ... ==========
  static const int headerC1 = 0xAA;
  static const int headerC2 = 0x55;

  /// Builds a packet for Protocol C
  /// Format: [0xAA] [0x55] [Cmd] [Data...] [Checksum]
  static Uint8List buildProtocolC(int command, List<int> data) {
    List<int> packet = [headerC1, headerC2, command, ...data];
    int checksum = packet.fold(0, (sum, item) => (sum + item) & 0xFF);
    packet.add(checksum);
    return Uint8List.fromList(packet);
  }

  /// Universal packet builder
  static Uint8List buildPacket(
    ProtocolType protocol,
    int command,
    List<int> data,
  ) {
    switch (protocol) {
      case ProtocolType.a:
        return buildProtocolA(command: command, data: data);
      case ProtocolType.b:
        return buildProtocolB(data: data);
      case ProtocolType.c:
        return buildProtocolC(command, data);
    }
  }

  /// Detects protocol from notify response
  static ProtocolType detectProtocol(List<int> response) {
    if (response.isEmpty) return ProtocolType.a;

    switch (response.first) {
      case 0x7E:
        return ProtocolType.a;
      case 0x55:
        return ProtocolType.b;
      case 0xAA:
        return ProtocolType.c;
      default:
        return ProtocolType.a;
    }
  }

  // ========== Protocol C Commands ==========
  static Uint8List startProtocolC() {
    return buildProtocolC(0x01, [0x01]);
  }

  static Uint8List stopProtocolC() {
    return buildProtocolC(0x01, [0x00]);
  }

  static Uint8List setIntensityC(int channel, int level) {
    return buildProtocolC(0x03, [channel, level]);
  }
}

class ProtocolACommand {
  final int command;
  final int param1; // Often Channel or Feature
  final int param2; // Often Level or State

  ProtocolACommand({
    required this.command,
    required this.param1,
    required this.param2,
  });

  @override
  String toString() {
    return 'ProtoA(Cmd: ${command.toRadixString(16)}, P1: ${param1.toRadixString(16)}, P2: $param2)';
  }
}

class DeviceStatus {
  final int levelA;
  final int levelB;
  final int levelC;
  final int flags;
  final bool powerOn;
  final List<int> rawBytes;

  DeviceStatus({
    required this.levelA,
    required this.levelB,
    required this.levelC,
    required this.flags,
    required this.powerOn,
    required this.rawBytes,
  });

  Map<String, dynamic> toMap() {
    return {
      'levelA': levelA,
      'levelB': levelB,
      'levelC': levelC,
      'flags': flags,
      'powerOn': powerOn,
    };
  }

  @override
  String toString() {
    return 'Status(A: $levelA, B: $levelB, C: $levelC, Power: $powerOn, Flags: ${flags.toRadixString(16)})';
  }
}
