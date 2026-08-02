import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neotask_pro/theme/app_theme.dart';
import 'package:neotask_pro/widgets/neo_app_bar_tabs.dart';

void main() {
  testWidgets('app bar tabs stay legible and bounded on desktop', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 500));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final controller = TabController(length: 3, vsync: const TestVSync());
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          appBar: AppBar(
            title: const Text('التصويتات'),
            bottom: NeoAppBarTabs(
              controller: controller,
              tabs: const [
                NeoAppBarTab(icon: Icons.campaign_outlined, label: 'نشط'),
                NeoAppBarTab(icon: Icons.edit_note_outlined, label: 'مسودة'),
                NeoAppBarTab(icon: Icons.cancel_outlined, label: 'مُلغى'),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.text('نشط'), findsOneWidget);
    expect(find.text('مسودة'), findsOneWidget);
    expect(find.text('مُلغى'), findsOneWidget);
    expect(tester.getSize(find.byType(NeoAppBarTabs)).width, 1440);
    expect(tester.getSize(find.byType(TabBar)).width, lessThanOrEqualTo(680));

    await tester.tap(find.text('مسودة'));
    await tester.pumpAndSettle();
    expect(controller.index, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('app bar tabs fit a narrow mobile viewport', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final controller = TabController(length: 2, vsync: const TestVSync());
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          appBar: AppBar(
            title: const Text('خطة العمل'),
            bottom: NeoAppBarTabs(
              controller: controller,
              maxWidth: 560,
              tabs: const [
                NeoAppBarTab(
                  icon: Icons.view_timeline_outlined,
                  label: 'الخط الزمني',
                ),
                NeoAppBarTab(icon: Icons.groups_outlined, label: 'عبء العمل'),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.text('الخط الزمني'), findsOneWidget);
    expect(find.text('عبء العمل'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
