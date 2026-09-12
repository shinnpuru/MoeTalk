import 'package:flutter/foundation.dart';

/// Which feature produced a task.
enum GenerationKind { drawing, voice }

/// Lifecycle of one generation attempt.
enum GenerationStatus { queued, running, completed, failed, cancelled }

/// One drawing or voice generation attempt, as listed in the settings log.
class GenerationTask {
  GenerationTask({
    required this.id,
    required this.kind,
    required this.backend,
    required this.title,
    required this.startedAt,
    this.status = GenerationStatus.running,
    this.detail = '',
  });

  final int id;
  final GenerationKind kind;

  /// `sd.cpp`, `Civitai`, `audio.cpp`, ...
  final String backend;

  /// Short single-line preview of the prompt or text.
  final String title;

  final DateTime startedAt;

  GenerationStatus status;
  String detail;
  String? error;
  DateTime? finishedAt;
  final List<String> log = [];

  bool get isActive =>
      status == GenerationStatus.queued || status == GenerationStatus.running;

  bool get isFailed => status == GenerationStatus.failed;

  /// Time spent so far (or total, once finished).
  Duration get duration =>
      (finishedAt ?? DateTime.now()).difference(startedAt);
}

/// Handle returned by [GenerationQueue.start]; the running code reports
/// progress and the final outcome through it.
class GenerationTaskHandle {
  GenerationTaskHandle(this._queue, this.task);

  final GenerationQueue _queue;
  final GenerationTask task;
  bool _settled = false;

  void queued({String? detail}) => _setStatus(GenerationStatus.queued, detail);

  void running({String? detail}) => _setStatus(GenerationStatus.running, detail);

  /// Appends a log line, e.g. the model name or a skipped LoRA.
  void note(String line) {
    final text = line.trim();
    if (text.isEmpty || _settled) return;
    task.log.add(text);
    _queue.notify();
  }

  void complete({String? detail}) =>
      _settle(GenerationStatus.completed, detail: detail);

  void cancel({String? detail}) =>
      _settle(GenerationStatus.cancelled, detail: detail);

  void fail(Object error, {String? detail}) => _settle(
        GenerationStatus.failed,
        detail: detail,
        error: describeGenerationError(error),
      );

  void _setStatus(GenerationStatus status, String? detail) {
    if (_settled) return;
    task.status = status;
    if (detail != null) task.detail = detail;
    _queue.notify();
  }

  void _settle(GenerationStatus status, {String? detail, String? error}) {
    if (_settled) return;
    _settled = true;
    task.status = status;
    if (detail != null) task.detail = detail;
    if (error != null) task.error = error;
    task.finishedAt = DateTime.now();
    _queue.trimHistory();
    _queue.notify();
  }
}

/// App-wide record of drawing and voice generation attempts.
///
/// Everything is in memory: it is a session log meant for watching progress
/// and diagnosing failures from the settings page.
class GenerationQueue extends ChangeNotifier {
  GenerationQueue({this.historyLimit = 50});

  static final GenerationQueue instance = GenerationQueue();

  /// How many finished tasks are kept.
  final int historyLimit;

  final List<GenerationTask> _tasks = [];
  int _nextId = 1;

  /// Active tasks first (newest first), then finished ones (newest first).
  List<GenerationTask> get tasks {
    final active = <GenerationTask>[];
    final finished = <GenerationTask>[];
    for (final task in _tasks) {
      (task.isActive ? active : finished).add(task);
    }
    return List.unmodifiable([...active, ...finished]);
  }

  int get activeCount => _tasks.where((task) => task.isActive).length;

  bool get isEmpty => _tasks.isEmpty;

  GenerationTaskHandle start({
    required GenerationKind kind,
    required String backend,
    required String title,
    GenerationStatus status = GenerationStatus.running,
    String detail = '',
  }) {
    final task = GenerationTask(
      id: _nextId++,
      kind: kind,
      backend: backend,
      title: summarizeGenerationTitle(title),
      startedAt: DateTime.now(),
      status: status,
      detail: detail,
    );
    _tasks.insert(0, task);
    trimHistory();
    notifyListeners();
    return GenerationTaskHandle(this, task);
  }

  /// Drops finished tasks, keeping the ones still running.
  void clear() {
    _tasks.removeWhere((task) => !task.isActive);
    notifyListeners();
  }

  /// Plain-text dump of every task, for pasting into a bug report.
  String describe() {
    final buffer = StringBuffer()
      ..writeln('MoeTalk generation log')
      ..writeln('generated: ${DateTime.now().toIso8601String()}');
    for (final task in tasks) {
      final kind = task.kind == GenerationKind.drawing ? 'drawing' : 'voice';
      buffer.writeln(
        '[$kind/${task.backend}] #${task.id} ${task.status.name} '
        '${_formatSeconds(task.duration)} — ${task.title}',
      );
      if (task.detail.isNotEmpty) buffer.writeln('  detail: ${task.detail}');
      for (final line in task.log) {
        buffer.writeln('  log: $line');
      }
      if (task.error != null) buffer.writeln('  error: ${task.error}');
    }
    return buffer.toString();
  }

  void notify() => notifyListeners();

  /// Drops the oldest finished tasks once more than [historyLimit] are kept.
  void trimHistory() {
    var finished = _tasks.where((task) => !task.isActive).length;
    if (finished <= historyLimit) return;
    for (var i = _tasks.length - 1; i >= 0 && finished > historyLimit; i--) {
      if (_tasks[i].isActive) continue;
      _tasks.removeAt(i);
      finished--;
    }
  }
}

/// Collapses whitespace and truncates long prompts for the task list.
String summarizeGenerationTitle(String text, {int maxLength = 140}) {
  final collapsed = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (collapsed.length <= maxLength) return collapsed;
  return '${collapsed.substring(0, maxLength - 1)}…';
}

/// Human readable message for any thrown object.
String describeGenerationError(Object error) {
  final text = error.toString();
  const prefix = 'Exception: ';
  return text.startsWith(prefix) ? text.substring(prefix.length) : text;
}

String _formatSeconds(Duration duration) =>
    '${(duration.inMilliseconds / 1000).toStringAsFixed(1)}s';
