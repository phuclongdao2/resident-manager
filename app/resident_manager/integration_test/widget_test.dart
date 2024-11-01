import "dart:math";

import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:integration_test/integration_test.dart";
import "package:resident_manager/main.dart";
import "package:resident_manager/src/config.dart";
import "package:resident_manager/src/state.dart";
import "package:resident_manager/src/widgets/home.dart";
import "package:resident_manager/src/widgets/login.dart";
import "package:resident_manager/src/widgets/register.dart";
import "package:resident_manager/src/widgets/admin/reg_queue.dart";
import "package:resident_manager/src/widgets/admin/residents.dart";
import "package:resident_manager/src/widgets/admin/rooms.dart";

final rng = Random();
const MAX_WAIT_DURATION = Duration(seconds: 10);

String randomString(int length) {
  const chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
  return String.fromCharCodes(Iterable.generate(length, (_) => chars.codeUnitAt(rng.nextInt(chars.length))));
}

String randomDigits(int length) {
  const chars = "0123456789";
  return String.fromCharCodes(Iterable.generate(length, (_) => chars.codeUnitAt(rng.nextInt(chars.length))));
}

Future<Finder> pumpUntilFound(
  bool Function(Widget) predicate,
  Matcher matcher,
  WidgetTester tester,
) async {
  final stopWatch = Stopwatch();
  while (true) {
    await tester.pumpAndSettle();
    try {
      final finder = find.byWidgetPredicate(predicate);
      expect(finder, matcher);

      return finder;
    } catch (_) {
      if (stopWatch.elapsed > MAX_WAIT_DURATION) {
        rethrow;
      }
    }

    await Future.delayed(const Duration(milliseconds: 500));
  }
}

Future<void> adminSearch(
  WidgetTester tester, {
  required String fullname,
  required int room,
  required String username,
}) async {
  // Open search interface
  await tester.tap(find.byIcon(Icons.search_outlined));
  await tester.pumpAndSettle();

  final searchDialog = find.byWidgetPredicate((widget) => widget is SimpleDialog);
  expect(searchDialog, findsOneWidget);

  final searchFields = find.descendant(
    of: searchDialog,
    matching: find.byWidgetPredicate((widget) => widget is TextFormField),
  );
  expect(searchFields, findsExactly(3));

  // Fill in search fields
  await tester.enterText(searchFields.at(0), fullname);
  await tester.enterText(searchFields.at(1), room.toString());
  await tester.enterText(searchFields.at(2), username);
  await tester.tap(find.descendant(of: searchDialog, matching: find.byIcon(Icons.done_outlined)));
  await tester.pumpAndSettle(MAX_WAIT_DURATION);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    "Administrator login",
    (tester) async {
      final state = ApplicationState();
      await state.prepare();
      await state.deauthorize(); // Start integration test without existing authorization data

      await tester.pumpWidget(MainApplication(state: state));
      await tester.pumpAndSettle();

      // Authorization fields
      final fields = find.byWidgetPredicate((widget) => widget is TextField);
      expect(fields, findsExactly(2));

      await tester.enterText(fields.at(0), DEFAULT_ADMIN_USERNAME);
      await tester.enterText(fields.at(1), DEFAULT_ADMIN_PASSWORD);

      // Press the "Login as administrator" button
      await tester.tap(find.byIcon(Icons.admin_panel_settings_outlined));
      await pumpUntilFound((widget) => widget is RegisterQueuePage, findsOneWidget, tester);

      // Open drawer
      await tester.tap(find.byIcon(Icons.menu_outlined));
      await tester.pumpAndSettle();

      // Open residents list
      await tester.tap(find.byIcon(Icons.people_outlined));
      await pumpUntilFound((widget) => widget is ResidentsPage, findsOneWidget, tester);

      // Open drawer
      await tester.tap(find.byIcon(Icons.menu_outlined));
      await tester.pumpAndSettle();

      // Open rooms list
      await tester.tap(find.byIcon(Icons.room_outlined));
      await pumpUntilFound((widget) => widget is RoomsPage, findsOneWidget, tester);

      // Open drawer
      await tester.tap(find.byIcon(Icons.menu_outlined));
      await tester.pumpAndSettle();

      // Logout
      await tester.tap(find.byIcon(Icons.logout_outlined));
      await tester.pumpAndSettle();

      expect(find.byWidgetPredicate((widget) => widget is LoginPage), findsOneWidget);
    },
  );

  testWidgets(
    "Resident registration",
    (tester) async {
      final state = ApplicationState();
      await state.prepare();
      await state.deauthorize(); // Start integration test without existing authorization data

      await tester.pumpWidget(MainApplication(state: state));
      await tester.pumpAndSettle();

      // Press the "Register as resident" button
      await tester.tap(find.byIcon(Icons.how_to_reg_outlined));
      await tester.pumpAndSettle();

      expect(find.byWidgetPredicate((widget) => widget is RegisterPage), findsOneWidget);

      // Registration form fields
      final registrationFields = find.byWidgetPredicate((widget) => widget is TextFormField);
      expect(registrationFields, findsExactly(8));

      var fullname = randomString(20); // Will append the string " (edited)" later
      var room = rng.nextInt(32766); // Will increase by 1 later
      var phone = randomDigits(10); // Will append 1 digit later
      var email = "$fullname@test.com"; // Will prepend the string "edited." later
      var username = randomString(15); // Will append 1 character later
      var password = randomString(15); // Will append 1 character later

      // Fill in registration fields
      await tester.enterText(registrationFields.at(0), fullname);
      await tester.enterText(registrationFields.at(1), room.toString());
      // Skip birthday
      await tester.enterText(registrationFields.at(3), phone);
      await tester.enterText(registrationFields.at(4), email);
      await tester.enterText(registrationFields.at(5), username);
      await tester.enterText(registrationFields.at(6), password);
      await tester.enterText(registrationFields.at(7), password);

      // Tap the "Register" button
      await tester.tap(find.byIcon(Icons.how_to_reg_outlined));
      await tester.pumpAndSettle(MAX_WAIT_DURATION);

      // Open drawer
      await tester.tap(find.byIcon(Icons.menu_outlined));
      await tester.pumpAndSettle();

      // Open login menu
      await tester.tap(find.byIcon(Icons.lock_outlined));
      await tester.pumpAndSettle();

      expect(find.byWidgetPredicate((widget) => widget is LoginPage), findsOneWidget);

      // Login as administrator
      final adminLoginFields = find.byWidgetPredicate((widget) => widget is TextField);
      expect(adminLoginFields, findsExactly(2));

      await tester.enterText(adminLoginFields.at(0), DEFAULT_ADMIN_USERNAME);
      await tester.enterText(adminLoginFields.at(1), DEFAULT_ADMIN_PASSWORD);

      // Press the "Login as administrator" button
      await tester.tap(find.byIcon(Icons.admin_panel_settings_outlined));

      // Successfully logged in as admin
      await pumpUntilFound((widget) => widget is RegisterQueuePage, findsOneWidget, tester);

      // Search for resident
      await adminSearch(tester, fullname: fullname, room: room, username: username);

      // Exactly 2 checkboxes: 1 for "Select all", 1 for our search result
      final checkboxes = find.byWidgetPredicate((widget) => widget is Checkbox);
      expect(checkboxes, findsExactly(2));

      // Toggle 3 times
      await tester.tap(checkboxes.first);
      await tester.tap(checkboxes.last);
      await tester.tap(checkboxes.first);
      await tester.pumpAndSettle();

      // Approve the registration request
      await tester.tap(find.byIcon(Icons.done_outlined));
      await tester.pumpAndSettle(MAX_WAIT_DURATION);

      // Open drawer
      await tester.tap(find.byIcon(Icons.menu_outlined));
      await tester.pumpAndSettle();

      // Logout
      await tester.tap(find.byIcon(Icons.logout_outlined));
      await tester.pumpAndSettle();

      expect(find.byWidgetPredicate((widget) => widget is LoginPage), findsOneWidget);

      // Login as the newly created resident user
      final loginFields = find.byWidgetPredicate((widget) => widget is TextField);
      expect(loginFields, findsExactly(2));

      await tester.enterText(loginFields.at(0), username);
      await tester.enterText(loginFields.at(1), password);

      // Press the "Login as resident" button
      await tester.tap(find.byIcon(Icons.login_outlined));

      // Successfully logged in as resident
      await pumpUntilFound((widget) => widget is HomePage, findsOneWidget, tester);

      // Open drawer
      await tester.tap(find.byIcon(Icons.menu_outlined));
      await tester.pumpAndSettle();

      // Logout
      await tester.tap(find.byIcon(Icons.logout_outlined));
      await tester.pumpAndSettle();

      expect(find.byWidgetPredicate((widget) => widget is LoginPage), findsOneWidget);

      // Login as administrator
      final adminLoginFields2 = find.byWidgetPredicate((widget) => widget is TextField);
      expect(adminLoginFields2, findsExactly(2));

      await tester.enterText(adminLoginFields2.at(0), DEFAULT_ADMIN_USERNAME);
      await tester.enterText(adminLoginFields2.at(1), DEFAULT_ADMIN_PASSWORD);

      // Press the "Login as administrator" button
      await tester.tap(find.byIcon(Icons.admin_panel_settings_outlined));

      // Successfully logged in as admin
      await pumpUntilFound((widget) => widget is RegisterQueuePage, findsOneWidget, tester);

      // Open drawer
      await tester.tap(find.byIcon(Icons.menu_outlined));
      await tester.pumpAndSettle();

      // View resident list
      await tester.tap(find.byIcon(Icons.people_outlined));
      await tester.pumpAndSettle();

      expect(find.byWidgetPredicate((widget) => widget is ResidentsPage), findsOneWidget);

      // Search for resident
      await adminSearch(tester, fullname: fullname, room: room, username: username);

      // Open the dialog to edit resident information
      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();

      final editDialog = find.byWidgetPredicate((widget) => widget is SimpleDialog);
      expect(editDialog, findsOneWidget);

      // Find edit fields
      final editFields = find.descendant(
        of: editDialog,
        matching: find.byWidgetPredicate((widget) => widget is TextFormField),
      );

      // Update information
      fullname = "$fullname (edited)";
      room = room + 1;
      phone = phone + randomDigits(1);
      email = "edited.$email";

      // Fill in edit fields
      await tester.enterText(editFields.at(0), fullname);
      await tester.enterText(editFields.at(1), room.toString());
      await tester.enterText(editFields.at(3), phone);
      await tester.enterText(editFields.at(4), email);
      await tester.tap(find.descendant(of: editDialog, matching: find.byIcon(Icons.done_outlined)));
      await tester.pumpAndSettle(MAX_WAIT_DURATION);

      // Now no result should match our search
      expect(find.byWidgetPredicate((widget) => widget is Checkbox), findsOneWidget);

      // Search the resident again using updated information
      await adminSearch(tester, fullname: fullname, room: room, username: username);

      // Exactly 2 checkboxes: 1 for "Select all", 1 for our search result
      final checkboxes2 = find.byWidgetPredicate((widget) => widget is Checkbox);
      expect(checkboxes2, findsExactly(2));

      // Toggle 3 times
      await tester.tap(checkboxes2.first);
      await tester.tap(checkboxes2.last);
      await tester.tap(checkboxes2.first);
      await tester.pumpAndSettle();

      // Delete the created account
      await tester.tap(find.byIcon(Icons.delete_outlined));
      await tester.pumpAndSettle(MAX_WAIT_DURATION);

      // Open drawer
      await tester.tap(find.byIcon(Icons.menu_outlined));
      await tester.pumpAndSettle();

      // Logout
      await tester.tap(find.byIcon(Icons.logout_outlined));
      await tester.pumpAndSettle();

      expect(find.byWidgetPredicate((widget) => widget is LoginPage), findsOneWidget);
    },
  );
}
