import 'package:flutter_test/flutter_test.dart';

import 'package:car_dashboard/main.dart';

void main() {
  testWidgets('CarDashboardApp builds without errors',
      (WidgetTester tester) async {
    await tester.pumpWidget(const CarDashboardApp());
    // Verify the app renders the dashboard screen
    expect(find.text('km/h'), findsOneWidget);
  });
}
