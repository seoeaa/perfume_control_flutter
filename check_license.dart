
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

void main() {
  try {
    print("License values: ${License.values}");
  } catch (e) {
    print("Error: $e");
  }
}
