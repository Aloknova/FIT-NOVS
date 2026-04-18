import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fitnova/src/app/app.dart';

void main() {
  testWidgets('FitNova app renders setup guidance without runtime env', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: FitNovaApp()));
    await tester.pumpAndSettle();

    expect(find.text('Environment setup required'), findsOneWidget);
    expect(find.textContaining('SUPABASE_URL'), findsOneWidget);
  });
}
