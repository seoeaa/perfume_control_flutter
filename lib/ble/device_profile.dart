import 'package:flutter_blue_plus/flutter_blue_plus.dart';

enum ProtocolType { a, b, c }

class DeviceProfile {
  final String name;
  final List<String> writeUuids;
  final List<String> notifyUuids;
  final ProtocolType protocol;

  DeviceProfile({
    required this.name,
    required this.writeUuids,
    required this.notifyUuids,
    required this.protocol,
  });
}

class DeviceProfileManager {
  static final List<DeviceProfile> profiles = [
    DeviceProfile(
      name: 'classic_ffe',
      // Some classic FFE boards expose two writable chars (ffe1 and ffe3).
      // Prefer ffe1 first: on a subset of Fresh Air devices ffe3 accepts
      // writes at BLE level, but the MCU ignores control commands there.
      // Keep ffe3 as fallback for older firmware variants.
      writeUuids: ['ffe1', 'ffe3'],
      notifyUuids: ['ffe2'],
      protocol: ProtocolType.a,
    ),
    DeviceProfile(
      name: 'classic_fff',
      writeUuids: ['fff2'],
      notifyUuids: ['fff1'],
      protocol: ProtocolType.c,
    ),
    DeviceProfile(
      name: 'new_board',
      writeUuids: ['00112433-4455-6677-8899-aabbccddeeff'],
      notifyUuids: ['00112333-4455-6677-8899-aabbccddeeff'],
      protocol: ProtocolType.c,
    ),
  ];

  static DeviceProfile? findProfile(List<BluetoothService> services) {
    final discovered = <String>{};
    for (final service in services) {
      for (final characteristic in service.characteristics) {
        discovered.add(characteristic.uuid.toString().toLowerCase());
      }
    }


    DeviceProfile? bestProfile;
    int bestScore = -1;

    for (final profile in profiles) {
      final matchedWrite = profile.writeUuids.where((u) => discovered.contains(u.toLowerCase())).toList();
      final matchedNotify = profile.notifyUuids.where((u) => discovered.contains(u.toLowerCase())).toList();

      final writeMatches = matchedWrite.length;
      final notifyMatches = matchedNotify.length;

      // Higher score for write matches
      final score = (writeMatches * 10) + notifyMatches;

      // SPECIFICITY: 128-bit UUIDs are much more important than 16-bit fff1/ffe1
      final specificity = [
        ...matchedWrite,
        ...matchedNotify,
      ].where((uuid) => uuid.length > 8).length;

      // If we have a 128-bit match, ignore 16-bit matches if they belong to a different profile
      // Or simply add a massive weight to specificity
      final totalScore = score + (specificity * 100);

      if (totalScore > bestScore && writeMatches > 0) {
        bestScore = totalScore;
        bestProfile = profile;
      }
    }

    return bestProfile;
  }

  static DeviceProfile? getProfileForProtocol(ProtocolType protocol) {
    // Return the most modern profile for this protocol
    return profiles.lastWhere((p) => p.protocol == protocol, 
      orElse: () => profiles.firstWhere((p) => p.protocol == protocol));
  }

  static List<String> getAllWriteUuids() {
    return profiles.expand((p) => p.writeUuids).toList();
  }

  static List<String> getAllNotifyUuids() {
    return profiles.expand((p) => p.notifyUuids).toList();
  }
}
