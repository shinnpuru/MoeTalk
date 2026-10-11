import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moetalk/configpage.dart';
import 'package:moetalk/i18n.dart';
import 'package:moetalk/utils.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _RealHttp extends HttpOverrides {}

void main() {
  setUp(() {
    I18n.locale = 'en';
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('validates URL and model before testing', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: ConfigPage(
        currentConfig: Config(name: '', baseUrl: '', apiKey: '', model: ''),
        updateFunc: (_) {},
      ),
    ));
    await tester.pumpAndSettle();
    final button = find.text('Test language model connection');
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.text('Enter a valid HTTP(S) API URL and a model name.'),
        findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets(
      'tests unsaved fields, prevents duplicate tests and clears stale results',
      (tester) async {
    final reply = Completer<void>();
    final received = Completer<Map<String, dynamic>>();
    var requestCount = 0;
    final server = (await tester.runAsync(() async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        requestCount++;
        final payload = jsonDecode(await utf8.decoder.bind(request).join())
            as Map<String, dynamic>;
        received.complete(payload);
        await reply.future;
        request.response.headers.contentType =
            ContentType('text', 'event-stream', charset: 'utf-8');
        request.response
            .write('data: {"choices":[{"delta":{"content":"OK"}}]}\n\n'
                'data: [DONE]\n\n');
        await request.response.close();
      });
      return server;
    }))!;
    addTearDown(() => server.close(force: true));
    await tester.binding.setSurfaceSize(const Size(800, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var saved = 0;
    await tester.pumpWidget(MaterialApp(
      home: ConfigPage(
        currentConfig:
            Config(name: 'unsaved', baseUrl: '', apiKey: '', model: ''),
        updateFunc: (_) => saved++,
      ),
    ));
    await tester.pumpAndSettle();
    final state = tester.state<ConfigPageState>(find.byType(ConfigPage));
    state.urlController.text =
        'http://${server.address.address}:${server.port}/v1';
    state.modelController.text = 'unsaved-model';
    final testButton = tester.widget<ElevatedButton>(find.ancestor(
        of: find.text('Test language model connection'),
        matching: find.byType(ElevatedButton)));
    await tester.runAsync(() async {
      HttpOverrides.runWithHttpOverrides(testButton.onPressed!, _RealHttp());
      testButton.onPressed!();
    });
    await tester.pump();
    expect(find.text('Testing connection…'), findsOneWidget);
    final busyButton = tester.widget<ElevatedButton>(find.ancestor(
        of: find.text('Testing connection…'),
        matching: find.byType(ElevatedButton)));
    expect(busyButton.onPressed, isNull);
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();
    await tester.runAsync(() async {
      expect(
          (await received.future.timeout(const Duration(seconds: 5)))['model'],
          'unsaved-model');
      reply.complete();
    });
    for (var attempt = 0; attempt < 100; attempt++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
      if (find.text('Connection successful').evaluate().isNotEmpty) break;
    }
    expect(find.text('Connection successful'), findsOneWidget);
    expect(requestCount, 1);
    expect(saved, 0);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getKeys(), isEmpty);
    state.modelController.text = 'edited-model';
    await tester.pump();
    expect(find.text('Connection successful'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });
}
