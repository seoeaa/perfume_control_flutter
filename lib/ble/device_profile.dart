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
      name: 'Fresh Air',
      // The "Good" board that works with Protocol B.
      // Often uses ffe1/ffe2 or fff1/fff2 but sends A5/55 packets.
      writeUuids: ['ffe1', 'fff2'],
      notifyUuids: ['ffe2', 'fff1'],
      protocol: ProtocolType.b,
    ),
    DeviceProfile(
      name: 'Unknown 64507067',
      // The "Research" board that matches this specific name/ID.
      writeUuids: ['fff2'],
      notifyUuids: ['fff1'],
      protocol: ProtocolType.c,
    ),
    DeviceProfile(
      name: 'Fresh Air (Legacy)',
      writeUuids: ['ffe1', 'ffe3'],
      notifyUuids: ['ffe2'],
      protocol: ProtocolType.a,
    ),
  ];

  static DeviceProfile? findProfile(BluetoothDevice device, List<BluetoothService> services) {
    final name = device.platformName.toLowerCase();
    
    // Exact name matching for known boards
    if (name.contains('64507067')) {
      return profiles.firstWhere((p) => p.name.contains('64507067'));
    }
    
    // Fresh Air boards often have "Fresh" or "Air" in the name
    if (name.contains('fresh') || name.contains('air')) {
      return profiles.firstWhere((p) => p.name == 'Fresh Air');
    }

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

      if (score > bestScore && writeMatches > 0) {
        bestScore = score;
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
