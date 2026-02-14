
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

void main() {
  test('print license values', () {
    try {
      print("License values: ${License.values}");
    } catch (e) {
      print("Error accessing License values: $e");
    }
  });
}
