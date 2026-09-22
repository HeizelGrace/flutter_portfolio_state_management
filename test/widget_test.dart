// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:portfolio_state_management/main.dart';

void main() {
  test('network health thresholds classify the minimum bandwidth', () {
    expect(
      NetworkDiagnosticService.classify(
        downloadMbps: 25,
        uploadMbps: 12,
        idlePingMs: 20,
        downloadPingMs: 30,
        uploadPingMs: 35,
      ),
      NetworkHealth.excellent,
    );
    expect(
      NetworkDiagnosticService.classify(
        downloadMbps: 8,
        uploadMbps: 2,
        idlePingMs: 40,
        downloadPingMs: 50,
        uploadPingMs: 55,
      ),
      NetworkHealth.fair,
    );
    expect(
      NetworkDiagnosticService.classify(
        downloadMbps: 1.5,
        uploadMbps: 1,
        idlePingMs: 40,
        downloadPingMs: 50,
        uploadPingMs: 55,
      ),
      NetworkHealth.poor,
    );
    expect(
      NetworkDiagnosticService.classify(
        downloadMbps: 20,
        uploadMbps: 20,
        idlePingMs: 1200,
        downloadPingMs: 80,
        uploadPingMs: 90,
      ),
      NetworkHealth.degraded,
    );
  });

  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => ThemeProvider(),
        child: const PortfolioApp(),
      ),
    );

    await tester.tap(find.text('State & responsive layout'));
    await tester.pumpAndSettle();

    expect(find.text('0'), findsOneWidget);
    expect(find.text('Responsive by default'), findsOneWidget);

    await tester.tap(find.text('Increment'));
    await tester.pump();

    expect(find.text('0'), findsNothing);
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('Network monitor activity smoke test', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => ThemeProvider(),
        child: const PortfolioApp(),
      ),
    );

    await tester.tap(find.text('Network monitor'));
    await tester.pumpAndSettle();

    expect(find.text('Activity 02 — Network Monitor'), findsOneWidget);
    expect(find.text('Active Interface'), findsOneWidget);
  });

  testWidgets('Theme toggle smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => ThemeProvider(),
        child: const PortfolioApp(),
      ),
    );

    await tester.tap(find.byIcon(Icons.tune));
    await tester.pumpAndSettle();

    expect(find.text('Preferences'), findsOneWidget);
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
  });
}
