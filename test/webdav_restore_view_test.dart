import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moetalk/i18n.dart';
import 'package:moetalk/webdav.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _RealHttp extends HttpOverrides {}

Future<void> _waitForDialog(WidgetTester tester) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
    if (find.byType(AlertDialog).evaluate().isNotEmpty) {
      await tester.pumpAndSettle();
      return;
    }
  }
  fail('Remote restore dialog did not open');
}

void main() {
  for (final confirm in [true, false]) {
    testWidgets(
        'remote configuration restore ${confirm ? 'applies' : 'cancels'} after confirmation',
        (tester) async {
      I18n.locale = 'en';
      await tester.binding.setSurfaceSize(const Size(800, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final payload = jsonEncode({
        'name': 'Restored character',
        'enabled': true,
        'count': 3,
        'webdav': ['https://example.com/dav/', 'test', 'secret'],
      });
      final server = (await tester.runAsync(() async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        server.listen((request) async {
          if (request.method == 'OPTIONS') {
            request.response.statusCode = 200;
          } else if (request.method == 'GET') {
            request.response.headers.contentType = ContentType.json;
            request.response.add(utf8.encode(payload));
          } else {
            request.response.statusCode = 405;
          }
          await request.response.close();
        });
        return server;
      }))!;
      addTearDown(() => server.close(force: true));
      SharedPreferences.setMockInitialValues({
        'existing': 'keep until confirmed',
        'webdav': [
          'http://${server.address.address}:${server.port}/dav/',
          '',
          ''
        ],
      });
      var configReloads = 0;
      var chatRestores = 0;
      await tester.pumpWidget(MaterialApp(
        home: WebdavPage(
          currentMessages: '[]',
          onRefresh: (_) => chatRestores++,
          onConfigRestored: () async => configReloads++,
        ),
      ));
      await tester.pumpAndSettle();
      final state = tester.state<WebdavPageState>(find.byType(WebdavPage));
      state.messageRecords = [
        ['Remote backup', '1779000000000.json', '']
      ];
      late Future<void> operation;
      await tester.runAsync(() async {
        operation = HttpOverrides.runWithHttpOverrides(
            () => state.loadItem(0), _RealHttp());
      });
      await _waitForDialog(tester);
      // The preview must not expose credentials from the downloaded JSON.
      expect(find.textContaining('secret'), findsNothing);
      await tester.tap(find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text(I18n.t('file_restore'))));
      await tester.pumpAndSettle();
      await _waitForDialog(tester);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('existing'), 'keep until confirmed');
      await tester.tap(find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text(I18n.t(confirm ? 'confirm' : 'cancel'))));
      await tester.pumpAndSettle();
      await tester
          .runAsync(() => operation.timeout(const Duration(seconds: 10)));
      await tester.pumpAndSettle();
      expect(chatRestores, 0);
      expect(configReloads, confirm ? 1 : 0);
      if (confirm) {
        expect(prefs.getString('name'), 'Restored character');
        expect(prefs.getBool('enabled'), isTrue);
        expect(prefs.getInt('count'), 3);
        expect(prefs.getStringList('webdav'),
            ['https://example.com/dav/', 'test', 'secret']);
        expect(prefs.get('existing'), isNull);
      } else {
        expect(prefs.getString('existing'), 'keep until confirmed');
        expect(prefs.get('name'), isNull);
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
