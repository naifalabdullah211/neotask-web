import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neotask_pro/theme/app_theme.dart';
import 'package:neotask_pro/widgets/neo_selection_field.dart';

void main() {
  testWidgets('uses one bottom sheet and returns the selected value', (
    tester,
  ) async {
    var selected = 'medium';

    Widget build() => MaterialApp(
      theme: AppTheme.lightTheme,
      home: StatefulBuilder(
        builder: (context, setState) => Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(20),
            child: NeoSelectionField<String>(
              label: 'الأولوية',
              value: selected,
              options: const [
                NeoSelectionOption(value: 'low', label: 'منخفضة'),
                NeoSelectionOption(value: 'medium', label: 'متوسطة'),
                NeoSelectionOption(value: 'high', label: 'عالية'),
              ],
              onChanged: (value) => setState(() => selected = value),
            ),
          ),
        ),
      ),
    );

    await tester.pumpWidget(build());
    expect(find.text('متوسطة'), findsOneWidget);

    await tester.tap(find.text('متوسطة'));
    await tester.pumpAndSettle();
    expect(find.text('الأولوية'), findsNWidgets(2));
    expect(find.text('عالية'), findsOneWidget);

    await tester.tap(find.text('عالية'));
    await tester.pumpAndSettle();
    expect(selected, 'high');
    expect(find.text('عالية'), findsOneWidget);
  });

  testWidgets('shows search automatically for long option lists', (
    tester,
  ) async {
    final options = List.generate(
      10,
      (index) => NeoSelectionOption(value: index, label: 'موظف $index'),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: NeoSelectionField<int>(
            label: 'الموظف',
            value: 0,
            options: options,
            onChanged: (_) {},
          ),
        ),
      ),
    );

    await tester.tap(find.text('موظف 0'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'موظف 9');
    await tester.pumpAndSettle();
    expect(find.text('موظف 9'), findsOneWidget);
    expect(find.text('موظف 1'), findsNothing);
  });
}
