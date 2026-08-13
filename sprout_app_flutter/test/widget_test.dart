import 'package:flutter_test/flutter_test.dart';
import 'package:sprout_app/main.dart';

void main() {
  test('Sprout application can be constructed', () {
    const app = SproutApp();
    expect(app, isA<SproutApp>());
  });
}
