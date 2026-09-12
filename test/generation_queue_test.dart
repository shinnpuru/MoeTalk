import 'package:flutter_test/flutter_test.dart';
import 'package:moetalk/generation_queue.dart';

void main() {
  group('GenerationQueue', () {
    test('tracks status transitions through the handle', () {
      final queue = GenerationQueue();
      final handle = queue.start(
        kind: GenerationKind.drawing,
        backend: 'sd.cpp',
        title: '1girl',
      );

      expect(queue.activeCount, 1);
      expect(handle.task.status, GenerationStatus.running);
      expect(queue.tasks.single.title, '1girl');

      handle.queued(detail: 'queued #2');
      expect(handle.task.status, GenerationStatus.queued);
      expect(handle.task.detail, 'queued #2');

      handle.running(detail: 'generating');
      handle.note('Model: waiIllustriousSDXL_v160');
      expect(handle.task.log, ['Model: waiIllustriousSDXL_v160']);

      handle.complete(detail: '832x1216 · 1800 KB');
      expect(handle.task.status, GenerationStatus.completed);
      expect(handle.task.detail, '832x1216 · 1800 KB');
      expect(queue.activeCount, 0);
      expect(handle.task.finishedAt, isNotNull);

      // A settled task ignores late updates from the running code.
      handle.note('late line');
      handle.fail('nope');
      expect(handle.task.log, ['Model: waiIllustriousSDXL_v160']);
      expect(handle.task.status, GenerationStatus.completed);
      expect(handle.task.error, isNull);
    });

    test('records failures and cancellations', () {
      final queue = GenerationQueue();
      queue.start(
        kind: GenerationKind.voice,
        backend: 'audio.cpp',
        title: '你好',
      ).fail(Exception('model missing'));

      queue.start(
        kind: GenerationKind.drawing,
        backend: 'sd.cpp',
        title: 'cancelled',
      ).cancel();

      expect(queue.activeCount, 0);
      expect(
        queue.tasks.firstWhere((task) => task.title == '你好').status,
        GenerationStatus.failed,
      );
      expect(
        queue.tasks.firstWhere((task) => task.title == '你好').error,
        'model missing',
      );
      expect(
        queue.tasks.firstWhere((task) => task.title == 'cancelled').status,
        GenerationStatus.cancelled,
      );
    });

    test('lists active tasks first, newest first', () {
      final queue = GenerationQueue();
      queue
          .start(kind: GenerationKind.voice, backend: 'audio.cpp', title: 'first')
          .complete();
      queue.start(
        kind: GenerationKind.drawing,
        backend: 'sd.cpp',
        title: 'second',
      );

      expect(queue.tasks.map((task) => task.title), ['second', 'first']);
      expect(queue.activeCount, 1);
    });

    test('clear() keeps running tasks and drops finished ones', () {
      final queue = GenerationQueue();
      queue
          .start(kind: GenerationKind.voice, backend: 'audio.cpp', title: 'done')
          .complete();
      queue.start(
        kind: GenerationKind.drawing,
        backend: 'sd.cpp',
        title: 'active',
      );

      queue.clear();
      expect(queue.tasks.map((task) => task.title), ['active']);
      expect(queue.isEmpty, isFalse);
    });

    test('trims finished history to the configured limit', () {
      final queue = GenerationQueue(historyLimit: 2);
      for (var i = 0; i < 5; i++) {
        queue
            .start(
              kind: GenerationKind.voice,
              backend: 'audio.cpp',
              title: 'task $i',
            )
            .complete();
      }

      expect(queue.tasks.map((task) => task.title), ['task 4', 'task 3']);
    });

    test('notifies listeners on every change', () {
      final queue = GenerationQueue();
      var notifications = 0;
      queue.addListener(() => notifications++);

      final handle = queue.start(
        kind: GenerationKind.drawing,
        backend: 'sd.cpp',
        title: 'prompt',
      );
      handle.note('Model: x');
      handle.complete();

      expect(notifications, 3);
    });

    test('describe() dumps everything for a bug report', () {
      final queue = GenerationQueue();
      final handle = queue.start(
        kind: GenerationKind.drawing,
        backend: 'sd.cpp',
        title: '1girl, cherry blossoms',
      );
      handle.note('Model: waiIllustriousSDXL_v160');
      handle.fail(StateError('server exploded'));

      final dump = queue.describe();
      expect(dump, contains('drawing/sd.cpp'));
      expect(dump, contains('failed'));
      expect(dump, contains('1girl, cherry blossoms'));
      expect(dump, contains('log: Model: waiIllustriousSDXL_v160'));
      expect(dump, contains('error: Bad state: server exploded'));
    });
  });

  group('helpers', () {
    test('summarizeGenerationTitle collapses whitespace and truncates', () {
      expect(summarizeGenerationTitle('  a\n b\tc '), 'a b c');

      final long = summarizeGenerationTitle('x' * 200);
      expect(long.length, 140);
      expect(long.endsWith('…'), isTrue);
    });

    test('describeGenerationError drops the Exception prefix', () {
      expect(describeGenerationError(Exception('boom')), 'boom');
      expect(describeGenerationError('plain failure'), 'plain failure');
    });
  });
}
