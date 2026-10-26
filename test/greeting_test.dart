import 'package:flutter_test/flutter_test.dart';
import 'package:street_signal/core/format.dart';

void main() {
  String at(int hour, [int minute = 0]) => greetingFor(DateTime(2026, 10, 26, hour, minute));

  test('morning from 05:00 to 11:59', () {
    expect(at(5), 'Good morning');
    expect(at(8, 30), 'Good morning');
    expect(at(11, 59), 'Good morning');
  });

  test('afternoon from 12:00 to 16:59', () {
    expect(at(12), 'Good afternoon');
    expect(at(14, 15), 'Good afternoon');
    expect(at(16, 59), 'Good afternoon');
  });

  test('evening from 17:00 to 04:59', () {
    expect(at(17), 'Good evening');
    expect(at(20, 20), 'Good evening');
    expect(at(23, 59), 'Good evening');
    expect(at(0, 30), 'Good evening');
    expect(at(4, 59), 'Good evening');
  });
}
