import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_school/main.dart';

void main() {
  testWidgets('App loads', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: SmartSchoolApp()));
    expect(find.text('Welcome Back!'), findsOneWidget);
  });
}
