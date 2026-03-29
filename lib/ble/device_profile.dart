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
    int bestSpecificity = -1;

    for (final profile in profiles) {
      final matchedWrite = profile.writeUuids.where(discovered.contains).toList();
      final matchedNotify = profile.notifyUuids.where(discovered.contains).toList();

      final writeMatches = matchedWrite.length;
      final notifyMatches = matchedNotify.length;

      // Prioritize write match, then notify match.
      final score = (writeMatches * 10) + notifyMatches;

      // 128-bit UUID profiles are typically more specific than legacy 16-bit FFF/FFE aliases.
      final specificity = [
        ...matchedWrite,
        ...matchedNotify,
      ].where((uuid) => uuid.length > 8).length;

      final isBetter = score > bestScore ||
          (score == bestScore && specificity > bestSpecificity);

      if (isBetter && writeMatches > 0) {
        bestScore = score;
        bestSpecificity = specificity;
        bestProfile = profile;
      }
    }

    return bestProfile;
  }

  static List<String> getAllWriteUuids() {
    return profiles.expand((p) => p.writeUuids).toList();
  }

  static List<String> getAllNotifyUuids() {
    return profiles.expand((p) => p.notifyUuids).toList();
  }
}
