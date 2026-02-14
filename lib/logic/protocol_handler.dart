import 'dart:typed_data';

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
    // Example: a5 00 13 60 25 28 05 05 f5 64 64 64 80 00 0d 05 05 00 0c 10 fa be 11
    if (data.length < 23 || data[0] != 0xA5) return null;

    try {
      // Hypothesized mapping:
      // Index 9: Level A (0-100)
      // Index 10: Level B (0-100)
      // Index 11: Level C (0-100)
      // Index 12: Flags (0x80 = Power On?)
      
      int levelA = data[9];
      int levelB = data[10];
      int levelC = data[11];
      int flags = data[12];
      
      bool powerOn = (flags & 0x80) != 0; 
      // Other flags?
      // 0x80 = 1000 0000. 
      // Maybe bit 0 is Fan? bit 1 is Ion?
      
      return DeviceStatus(
        levelA: levelA,
        levelB: levelB,
        levelC: levelC,
        flags: flags,
        powerOn: powerOn,
      );
    } catch (e) {
      return null;
    }
  }
  /// Parses Protocol A Packet (starting with 0x7E)
  static ProtocolACommand? parseProtocolA(List<int> data) {
    // Example: 7e 06 02 05 01 ff ff 00 ef
    // Header: 7E
    // Length: 06 (excluding header/footer?) - actually length of payload + markers? 02 05 01 ff ff 00 = 6 bytes? No.
    // Let's look at buildProtocolA: 7E [Cmd] [Data...] [FF FF 00] EF
    // Received: 7E 06 02 05 01 FF FF 00 EF
    // 06 = Length of [02 05 01 FF FF 00]? 6 bytes. Yes.
    // Cmd = 02 ?? Or is 02 the command and 05 01 the data?
    // In build: setIntensityA used command 0x06, data [0x02, channel+5, level]
    // The response seems to be: 7E [Len] [Cmd=02?] [Channel] [Level] [Markers] EF
    
    if (data.length < 5 || data[0] != 0x7E) return null;

    try {
      int len = data[1];
      int cmd = data[2]; // 0x02 based on logs
      
      if (cmd == 0x02) {
        int param1 = data[3]; // Channel + 5 (5=A, 6=B, 7=C)
        int param2 = data[4]; // Level (0, 1, 2, 3)
        // 0x02 0x01 = Ion/Fragrance On/Off?
        // 0x02 0x02 = Ion/Fragrance?
        
        return ProtocolACommand(
          command: cmd,
          param1: param1,
          param2: param2,
        );
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}

class ProtocolACommand {
  final int command;
  final int param1; // Often Channel or Feature
  final int param2; // Often Level or State

  ProtocolACommand({required this.command, required this.param1, required this.param2});

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

  DeviceStatus({
    required this.levelA,
    required this.levelB,
    required this.levelC,
    required this.flags,
    required this.powerOn,
  });

  @override
  String toString() {
    return 'Status(A: $levelA, B: $levelB, C: $levelC, Power: $powerOn, Flags: ${flags.toRadixString(16)})';
  }
}
