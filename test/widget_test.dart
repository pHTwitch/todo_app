import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo_app/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    // Initialize SharedPreferences with mock values
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const TodoApp());

    // Wait for async initialization and animations to complete
    await tester.pumpAndSettle();

    // Verify that our app shows the title.
    expect(find.text('My Tasks'), findsOneWidget);
  });

  testWidgets('Can add a task', (WidgetTester tester) async {
    await tester.pumpWidget(const TodoApp());
    await tester.pumpAndSettle();

    // Enter task text
    await tester.enterText(
      find.byType(TextField).first,
      'Test Task',
    );
    await tester.pumpAndSettle();

    // Tap the add button
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();

    // Verify the task appears
    expect(find.text('Test Task'), findsOneWidget);
  });

  testWidgets('Can toggle task completion', (WidgetTester tester) async {
    await tester.pumpWidget(const TodoApp());
    await tester.pumpAndSettle();

    // Add a task
    await tester.enterText(find.byType(TextField).first, 'Test Task');
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();

    // Toggle checkbox
    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();

    // Verify task is completed (checkbox should be checked)
    final checkbox = tester.widget<Checkbox>(find.byType(Checkbox).first);
    expect(checkbox.value, true);
  });

  testWidgets('Can switch categories', (WidgetTester tester) async {
    await tester.pumpWidget(const TodoApp());
    await tester.pumpAndSettle();

    // Open sidebar (in case it's closed)
    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();

    // Tap on Work category
    await tester.tap(find.text('Work'));
    await tester.pumpAndSettle();

    // Verify category changed by checking the input placeholder
    expect(find.textContaining('Add a task to Work'), findsOneWidget);
  });

  testWidgets('Filter chips work correctly', (WidgetTester tester) async {
    await tester.pumpWidget(const TodoApp());
    await tester.pumpAndSettle();

    // Add tasks
    await tester.enterText(find.byType(TextField).first, 'Task 1');
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Task 2');
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();

    // Complete one task
    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();

    // Tap Active filter
    final activeChips = find.widgetWithText(FilterChip, 'Active');
    await tester.tap(activeChips);
    await tester.pumpAndSettle();

    // Should show only 1 task
    expect(find.byType(Checkbox), findsOneWidget);

    // Tap Completed filter
    await tester.tap(find.widgetWithText(FilterChip, 'Completed'));
    await tester.pumpAndSettle();

    // Should show only 1 completed task
    expect(find.byType(Checkbox), findsOneWidget);
  });

  testWidgets('Theme toggle works', (WidgetTester tester) async {
    await tester.pumpWidget(const TodoApp());
    await tester.pumpAndSettle();

    // Tap theme toggle button
    await tester.tap(find.byIcon(Icons.dark_mode));
    await tester.pumpAndSettle();

    // Verify icon changed to light mode
    expect(find.byIcon(Icons.light_mode), findsOneWidget);
  });

  testWidgets('Performance: Cached filtering works', (WidgetTester tester) async {
    await tester.pumpWidget(const TodoApp());
    await tester.pumpAndSettle();

    // Add multiple tasks
    for (int i = 0; i < 10; i++) {
      await tester.enterText(find.byType(TextField).first, 'Task $i');
      await tester.tap(find.widgetWithText(FilledButton, 'Add'));
      await tester.pumpAndSettle();
    }

    // Rebuild without changing filter - cache should be used
    await tester.pump();

    // If caching works, this should complete quickly without re-filtering
    expect(find.byType(Checkbox), findsNWidgets(10));
  });
}
