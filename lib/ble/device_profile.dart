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
      writeUuids: ['ffe1'],
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
    for (final profile in profiles) {
      for (final service in services) {
        for (final characteristic in service.characteristics) {
          final uuid = characteristic.uuid.toString().toLowerCase();
          if (profile.writeUuids.contains(uuid)) {
            return profile;
          }
        }
      }
    }
    return null;
  }

  static List<String> getAllWriteUuids() {
    return profiles.expand((p) => p.writeUuids).toList();
  }

  static List<String> getAllNotifyUuids() {
    return profiles.expand((p) => p.notifyUuids).toList();
  }
}
