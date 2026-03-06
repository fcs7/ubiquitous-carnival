import 'package:flutter_test/flutter_test.dart';
import 'package:muglia/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const MugliaApp());
    expect(find.text('Muglia'), findsAny);
  });
}
