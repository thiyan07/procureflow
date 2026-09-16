import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:procureflow/main.dart';

void main() {
  testWidgets('App loads and navigates to login when unauthenticated', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const ProviderScope(child: ProcureFlowApp()));
    await tester.pumpAndSettle(const Duration(seconds: 3));
    expect(find.text('Login'), findsWidgets);
  });
}
