import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:moetalk/i18n.dart';
import 'package:moetalk/main.dart';
import 'package:moetalk/prompteditor.dart';
import 'package:moetalk/storage.dart';
import 'package:moetalk/utils.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _RealHttp extends HttpOverrides {}

String _image(int red) =>
    'data:image/png;base64,${base64Encode(img.encodePng(img.Image(width: 2, height: 2)..setPixelRgb(0, 0, red, 0, 0)))}';

Future<MainPageState> _main(WidgetTester tester,
    {List<Message> messages = const [],
    Map<String, Object> extra = const {}}) async {
  SharedPreferences.setMockInitialValues({
    'language': 'en',
    'api_test': ['http://127.0.0.1:1/v1/', '', 'test'],
    'temp_history': msgListToJson(messages),
    ...extra,
  });
  await tester.pumpWidget(const MaterialApp(home: MainPage()));
  await tester.pumpAndSettle();
  return tester.state<MainPageState>(find.byType(MainPage));
}

void main() {
  testWidgets(
      'horizontal swipes cycle context images without changing dialogue',
      (tester) async {
    final first = _image(100);
    final second = _image(200);
    final state = await _main(tester, messages: [
      Message(type: Message.assistant, message: 'Keep this dialogue'),
      Message(type: Message.image, message: first),
      Message(type: Message.image, message: second),
    ]);
    List<int> pixels() => (state.backgroundImage!.image as MemoryImage).bytes;
    final firstBytes = base64Decode(first.split(',').last);
    final secondBytes = base64Decode(second.split(',').last);
    expect(pixels(), secondBytes);
    final surface = find.byKey(const ValueKey('chat-background-gesture'));
    await tester.drag(surface, const Offset(-160, 0));
    await tester.pumpAndSettle();
    expect(pixels(), firstBytes);
    expect(find.text('Keep this dialogue'), findsOneWidget);
    await tester.drag(surface, const Offset(160, 0));
    await tester.pumpAndSettle();
    expect(pixels(), secondBytes);
    expect(state.messages, hasLength(3));
    // Toggling to the backlog must preserve the swipe gesture.
    await tester.longPress(surface);
    await tester.pumpAndSettle();
    await tester.drag(surface, const Offset(-160, 0));
    await tester.pumpAndSettle();
    expect(pixels(), firstBytes);
    await tester.pumpWidget(const SizedBox());
  });

  for (final withImage in [false, true]) {
    testWidgets('swiping with ${withImage ? 'one image' : 'no images'} is safe',
        (tester) async {
      final state = await _main(tester, messages: [
        Message(type: Message.assistant, message: 'Hello'),
        if (withImage) Message(type: Message.image, message: _image(100)),
      ]);
      final original = state.backgroundImage!.image;
      for (final dx in [-150.0, 150.0]) {
        await tester.drag(find.byKey(const ValueKey('chat-background-gesture')),
            Offset(dx, 0));
        await tester.pumpAndSettle();
      }
      if (withImage) {
        expect((state.backgroundImage!.image as MemoryImage).bytes,
            (original as MemoryImage).bytes);
      } else {
        expect(state.backgroundImage!.image, original);
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('image-only context stays valid when advancing dialogue',
      (tester) async {
    await _main(tester, messages: [
      Message(type: Message.image, message: _image(100)),
    ]);
    await tester.tap(find.byKey(const ValueKey('chat-background-gesture')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('multiple story toggles combine context and survive reopening',
      (tester) async {
    final state = await _main(tester, extra: {
      for (final id in ['1', '2'])
        'history_$id': [
          'Story $id',
          msgListToJson([Message(type: Message.system, message: 'World $id')]),
        ],
    });
    await tester.tap(find.text('Story'));
    await tester.pumpAndSettle();
    expect(find.byType(Checkbox), findsNWidgets(2));
    for (var index = 0; index < 2; index++) {
      await tester.tap(find.byType(Checkbox).at(index));
      await tester.pumpAndSettle();
    }
    expect(state.currentStories, hasLength(2));
    final prompt = await parseMsg([], state.storyContext, []);
    expect(
        prompt,
        containsAll([
          ['system', 'World 1'],
          ['system', 'World 2'],
        ]));
    expect(await getEnabledStoryIds(), ['2', '1']);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(const MaterialApp(home: MainPage()));
    await tester.pumpAndSettle();
    final reopened = tester.state<MainPageState>(find.byType(MainPage));
    expect(reopened.currentStories.map((s) => s[1]), ['2', '1']);
    await tester.tap(find.text('Story'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    expect(reopened.storyContext.map((m) => m.message), ['World 1']);
    expect(await getEnabledStoryIds(), ['1']);
    await updateHistory(
        '1',
        msgListToJson([
          Message(type: Message.system, message: 'Edited world'),
        ]),
        'Story 1');
    await tester.tap(find.text('Chat'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Story'));
    await tester.pumpAndSettle();
    expect(reopened.storyContext.map((m) => m.message), ['Edited world']);
    await tester.pumpWidget(const SizedBox());
  });

  test('editing and deleting enabled stories preserves other selections',
      () async {
    SharedPreferences.setMockInitialValues({
      'history_1': ['First', '[]'],
      'history_2': ['Second', '[]'],
      'enabled_story_ids': ['1', '2'],
    });
    await updateHistory('1', '["edited"]', 'First');
    expect(await getEnabledStoryIds(), ['1', '2']);
    expect(
        (await getHistorys()).firstWhere((s) => s[1] == '1')[2], '["edited"]');
    await deleteHistory('history_1');
    expect(await getEnabledStoryIds(), ['2']);
    expect((await getHistorys()).single[1], '2');
  });

  testWidgets('character reference checkbox starts unchecked and toggles',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    SharedPreferences.setMockInitialValues({});
    I18n.locale = 'en';
    await tester.pumpWidget(const MaterialApp(home: PromptEditor()));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('AI 生成角色卡'));
    await tester.pumpAndSettle();
    expect(tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
        isFalse);
    await tester.tap(find.text('Reference current character card'));
    await tester.pumpAndSettle();
    expect(tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
        isTrue);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
  });

  test('character generation includes reference only when requested', () {
    expect(buildCharacterGenerationMessages('generator', 'new request'), [
      ['system', 'generator'],
      ['user', 'new request'],
    ]);
    const card = {
      'name': 'Alice',
      'description': 'Quiet wizard',
      'first_mes': 'Hi'
    };
    final prompt = buildCharacterGenerationMessages('generator', 'new request',
        reference: card);
    expect(prompt.last, ['user', 'new request']);
    expect(prompt[1][1], contains(jsonEncode(card)));
  });

  for (final reference in [false, true]) {
    testWidgets(
        'generation request sends editor contents with reference=$reference',
        (tester) async {
      final payloads = <Map<String, dynamic>>[];
      final server = (await tester.runAsync(() async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        server.listen((request) async {
          payloads.add(jsonDecode(await utf8.decoder.bind(request).join())
              as Map<String, dynamic>);
          request.response.headers.contentType =
              ContentType('text', 'event-stream', charset: 'utf-8');
          final card = jsonEncode({
            'name': 'Generated',
            'description': 'Generated description',
            'first_mes': 'Greetings',
            'draw_char_prompt': 'wizard',
          });
          request.response.write('data: ${jsonEncode({
                'choices': [
                  {
                    'delta': {'content': card}
                  }
                ]
              })}\n\ndata: [DONE]\n\n');
          await request.response.close();
        });
        return server;
      }))!;
      addTearDown(() => server.close(force: true));
      SharedPreferences.setMockInitialValues({
        'api_test': ['http://127.0.0.1:${server.port}/v1', 'test-key', 'test'],
        'name': 'Saved name',
        'description': 'Saved description',
      });
      I18n.locale = 'en';
      await tester.pumpWidget(const MaterialApp(home: PromptEditor()));
      await tester.pumpAndSettle();
      final editor = tester.state<PromptEditorState>(find.byType(PromptEditor));
      editor.studentNameController.text = 'Unsaved name';
      editor.controller.text = 'Unsaved description';
      editor.originMsgController.text = 'Unsaved greeting';
      editor.drawCharPromptController.text = 'silver hair';
      await tester.tap(find.byTooltip('AI 生成角色卡'));
      await tester.pumpAndSettle();
      if (reference) await tester.tap(find.byType(CheckboxListTile));
      await tester.enterText(find.byType(TextField), 'Create a new wizard');
      await tester.runAsync(() async {
        await HttpOverrides.runWithHttpOverrides(() async {
          await tester.tap(find.descendant(
              of: find.byType(AlertDialog), matching: find.text('Confirm')));
          for (var attempt = 0; attempt < 100 && payloads.isEmpty; attempt++) {
            await Future<void>.delayed(const Duration(milliseconds: 20));
          }
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }, _RealHttp());
      });
      await tester.pumpAndSettle();
      expect(payloads, hasLength(1));
      final messages = payloads.single['messages'] as List;
      expect(messages.last['content'], 'Create a new wizard');
      final sent = jsonEncode(messages);
      for (final value in [
        'Unsaved name',
        'Unsaved description',
        'Unsaved greeting',
        'silver hair'
      ]) {
        expect(sent.contains(value), reference);
      }
      expect(editor.studentNameController.text, 'Generated');
      await tester.pumpWidget(const SizedBox());
    });
  }
}
