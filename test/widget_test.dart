import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:adventskalender/app/app.dart';
import 'package:adventskalender/core/app_dependencies.dart';
import 'package:adventskalender/core/services/link_preview_service.dart';

Future<void> signIn(WidgetTester tester, String email) async {
  await tester.enterText(find.widgetWithText(TextField, 'Email'), email);
  await tester.enterText(find.widgetWithText(TextField, 'Password'), 'advent');
  await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
  await tester.pumpAndSettle();
}

Future<void> signOut(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Account'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Sign out'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Carl fills a door and Mariana receives it on its day', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    // Sparkling pouches wiggle forever unless animations are reduced.
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    final dependencies = AppDependencies.demo(
      now: () => DateTime(2026, 12, 3, 9),
      linkPreviews: LinkPreviewService(
        client: MockClient((_) async => http.Response('', 404)),
      ),
    );
    await tester.pumpWidget(AdventApp(dependencies: dependencies));
    await tester.pumpAndSettle();

    // Carl prepares door 3 (today) and door 4 (tomorrow) for Mariana.
    await signIn(tester, 'carl@demo');
    expect(find.text('My tree'), findsOneWidget);
    await tester.tap(find.text('Prepare'));
    await tester.pumpAndSettle();

    for (final (door, message) in [(3, 'Coffee date?'), (4, 'Tomorrow!')]) {
      await tester.tap(find.byKey(ValueKey('door-$door')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save surprise'));
      await tester.pumpAndSettle();
      expect(find.text('Add a message, a link, or a file.'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextField, 'Message'),
        message,
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Link (optional)'),
        'example.com/song',
      );
      await tester.tap(find.text('Save surprise'));
      await tester.pumpAndSettle();
    }
    expect(find.textContaining('2 of 24 pouches filled'), findsOneWidget);
    await signOut(tester);

    // Mariana sees door 3, while door 4 stays locked until tomorrow.
    await signIn(tester, 'mariana@demo');
    expect(find.byTooltip('Door 3: ready to open'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('door-4')));
    await tester.pumpAndSettle();
    expect(find.text('Door 4 opens on 4 December.'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('door-3')));
    await tester.pumpAndSettle();
    expect(find.text('From Carl'), findsOneWidget);
    expect(find.text('Coffee date?'), findsOneWidget);
    expect(find.text('https://example.com/song'), findsOneWidget);
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Door 3: opened'), findsOneWidget);

    await tester.tap(find.text('Gallery').last);
    await tester.pumpAndSettle();
    expect(find.text('Door 3 · 2026'), findsOneWidget);
    expect(find.text('Message · link'), findsOneWidget);
    expect(find.text('Door 4 · 2026'), findsNothing);
    await signOut(tester);

    // Carl can see that Mariana opened door 3.
    await signIn(tester, 'carl@demo');
    await tester.tap(find.text('Prepare'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Door 3: opened by Mariana'), findsOneWidget);
    expect(find.byTooltip('Door 4: ready for Mariana'), findsOneWidget);
  });
}
