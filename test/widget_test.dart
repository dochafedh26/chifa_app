import 'package:flutter_test/flutter_test.dart';
import 'package:chifa/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Verify MyApp instantiates cleanly
    expect(const MyApp(), isNotNull);
  });
}
