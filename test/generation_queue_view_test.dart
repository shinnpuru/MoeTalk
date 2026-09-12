import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moetalk/generation_queue.dart';
import 'package:moetalk/generation_queue_view.dart';
import 'package:moetalk/i18n.dart';

Widget _panel() => const MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: GenerationQueuePanel())),
    );

void main() {
  setUp(() => I18n.locale = 'en');

  testWidgets('shows an empty state before anything runs', (tester) async {
    await tester.pumpWidget(_panel());
    expect(find.text('Queue & Logs'), findsOneWidget);
    expect(find.text('No drawing or voice task yet.'), findsOneWidget);

    // Dispose the panel so its refresh timer is cancelled.
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('renders status, prompt, log lines and errors', (tester) async {
    final queue = GenerationQueue.instance;
    final drawing = queue.start(
      kind: GenerationKind.drawing,
      backend: 'sd.cpp',
      title: '1girl, cherry blossoms',
    );
    drawing.note('Model: waiIllustriousSDXL_v160');
    drawing.complete(detail: '832x1216 · 1800 KB');

    final voice = queue.start(
      kind: GenerationKind.voice,
      backend: 'audio.cpp',
      title: '你好，老师。',
    );
    voice.fail('未配置模型 ID');

    await tester.pumpWidget(_panel());
    await tester.pump();

    expect(find.text('Drawing · sd.cpp'), findsOneWidget);
    expect(find.text('Voice · audio.cpp'), findsOneWidget);
    expect(find.text('1girl, cherry blossoms'), findsOneWidget);
    expect(find.textContaining('completed'), findsWidgets);
    expect(find.textContaining('failed'), findsWidgets);
    expect(find.textContaining('832x1216'), findsOneWidget);
    expect(find.textContaining('Error: 未配置模型 ID'), findsOneWidget);

    // A running task is reported as running until it settles.
    final running = queue.start(
      kind: GenerationKind.drawing,
      backend: 'sd.cpp',
      title: 'still going',
    );
    await tester.pump();
    expect(find.textContaining('running'), findsWidgets);
    running.cancel();
    await tester.pump();
    expect(find.textContaining('cancelled'), findsWidgets);

    // Expanding a tile reveals the log recorded for that task.
    await tester.tap(find.ancestor(
      of: find.text('1girl, cherry blossoms'),
      matching: find.byType(ExpansionTile),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('Model: waiIllustriousSDXL_v160'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('copies the whole log to the clipboard', (tester) async {
    final queue = GenerationQueue.instance;
    queue
        .start(kind: GenerationKind.drawing, backend: 'sd.cpp', title: 'copy me')
        .note('Model: copy-target');

    final clipboardCalls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') clipboardCalls.add(call);
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    await tester.pumpWidget(_panel());
    await tester.pump();
    await tester.tap(find.byTooltip('Copy all logs'));
    await tester.pump();

    expect(clipboardCalls, hasLength(1));
    final text = (clipboardCalls.single.arguments as Map)['text'] as String;
    expect(text, contains('copy me'));
    expect(text, contains('log: Model: copy-target'));

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('clear removes finished entries but keeps running ones',
      (tester) async {
    final queue = GenerationQueue.instance;
    queue
        .start(kind: GenerationKind.voice, backend: 'Civitai', title: 'finished')
        .complete();
    queue.start(
      kind: GenerationKind.voice,
      backend: 'audio.cpp',
      title: 'in flight',
    );

    await tester.pumpWidget(_panel());
    await tester.pump();
    expect(find.text('finished'), findsOneWidget);

    await tester.tap(find.byTooltip('Clear finished entries'));
    await tester.pump();

    expect(find.text('finished'), findsNothing);
    expect(find.text('in flight'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });
}
