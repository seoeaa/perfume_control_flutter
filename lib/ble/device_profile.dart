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
      // Prefer ffe3 when available because commands are accepted there on
      // devices that only stream status on ffe2.
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
    int bestScore = 0;

    for (final profile in profiles) {
      final writeMatches = profile.writeUuids.where(discovered.contains).length;
      final notifyMatches = profile.notifyUuids.where(discovered.contains).length;

      // Prioritize write match, then notify match.
      final score = (writeMatches * 10) + notifyMatches;

      if (score > bestScore && writeMatches > 0) {
        bestScore = score;
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
