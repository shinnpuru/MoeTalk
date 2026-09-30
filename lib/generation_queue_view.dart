import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;

import 'generation_queue.dart';
import 'i18n.dart';
import 'utils.dart' show snackBarAlert;

/// Dedicated page for the live generation queue and logs.
class GenerationQueuePage extends StatelessWidget {
  const GenerationQueuePage({super.key});

  Future<void> _copyLog(BuildContext context) async {
    await Clipboard.setData(
      ClipboardData(text: GenerationQueue.instance.describe()),
    );
    if (!context.mounted) return;
    snackBarAlert(context, I18n.t('generation_log_copied'));
  }

  @override
  Widget build(BuildContext context) {
    final queue = GenerationQueue.instance;
    return Scaffold(
      appBar: AppBar(
        title: Text(I18n.t('generation_queue')),
        backgroundColor: const Color(0xfff2a0ac),
        foregroundColor: Colors.white,
        actions: [
          ListenableBuilder(
            listenable: queue,
            builder: (context, _) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: I18n.t('generation_copy_log'),
                  icon: const Icon(Icons.copy_all),
                  onPressed: queue.isEmpty ? null : () => _copyLog(context),
                ),
                IconButton(
                  tooltip: I18n.t('generation_clear_log'),
                  icon: const Icon(Icons.delete_sweep),
                  onPressed: queue.isEmpty ? null : queue.clear,
                ),
              ],
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          children: const [GenerationQueuePanel()],
        ),
      ),
    );
  }
}

/// Live queue/log panel used by [GenerationQueuePage].
class GenerationQueuePanel extends StatefulWidget {
  const GenerationQueuePanel({super.key});

  @override
  State<GenerationQueuePanel> createState() => _GenerationQueuePanelState();
}

class _GenerationQueuePanelState extends State<GenerationQueuePanel> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // Keeps the elapsed time of running tasks ticking.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (GenerationQueue.instance.activeCount == 0) return;
      setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final queue = GenerationQueue.instance;
    return ListenableBuilder(
      listenable: queue,
      builder: (context, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final task in queue.tasks)
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.0),
                ),
                child: _GenerationTaskTile(task: task),
              ),
          ],
        );
      },
    );
  }
}

class _GenerationTaskTile extends StatelessWidget {
  final GenerationTask task;

  const _GenerationTaskTile({required this.task});

  @override
  Widget build(BuildContext context) {
    final kindLabel = task.kind == GenerationKind.drawing
        ? I18n.t('generation_kind_drawing')
        : I18n.t('generation_kind_voice');
    final elapsed =
        '${(task.duration.inMilliseconds / 1000).toStringAsFixed(1)}s';
    final details = <String>[
      _statusLabel(task.status),
      if (task.detail.isNotEmpty) task.detail,
      elapsed,
    ].join(' · ');

    return ExpansionTile(
      dense: true,
      leading: Icon(
        task.kind == GenerationKind.drawing
            ? Icons.image
            : Icons.record_voice_over,
        color: _statusColor(task.status),
      ),
      title: Text(
        '$kindLabel · ${task.backend}',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (task.title.isNotEmpty)
            Text(
              task.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          Text(
            details,
            style: TextStyle(
              fontSize: 12,
              color: _statusColor(task.status),
            ),
          ),
          if (task.error != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '${I18n.t('generation_error')}: ${task.error}',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: Colors.red),
              ),
            ),
        ],
      ),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      children: [
        if (task.log.isEmpty && task.error == null)
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              I18n.t('generation_no_details'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        if (task.log.isNotEmpty)
          Align(
            alignment: Alignment.centerLeft,
            child: SelectableText(
              task.log.join('\n'),
              style: const TextStyle(fontSize: 12, fontFamily: 'Courier'),
            ),
          ),
        if (task.error != null)
          Align(
            alignment: Alignment.centerLeft,
            child: SelectableText(
              task.error!,
              style: const TextStyle(fontSize: 12, color: Colors.red),
            ),
          ),
      ],
    );
  }

  String _statusLabel(GenerationStatus status) {
    switch (status) {
      case GenerationStatus.queued:
        return I18n.t('generation_status_queued');
      case GenerationStatus.running:
        return I18n.t('generation_status_running');
      case GenerationStatus.completed:
        return I18n.t('generation_status_completed');
      case GenerationStatus.failed:
        return I18n.t('generation_status_failed');
      case GenerationStatus.cancelled:
        return I18n.t('generation_status_cancelled');
    }
  }

  Color _statusColor(GenerationStatus status) {
    switch (status) {
      case GenerationStatus.queued:
        return Colors.orange;
      case GenerationStatus.running:
        return Colors.blue;
      case GenerationStatus.completed:
        return Colors.green;
      case GenerationStatus.failed:
        return Colors.red;
      case GenerationStatus.cancelled:
        return Colors.grey;
    }
  }
}
