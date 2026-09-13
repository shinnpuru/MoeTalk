// ignore_for_file: use_build_context_synchronously

import 'dart:convert';

import 'package:flutter/material.dart';
import 'webdav_backup_store.dart';
import 'storage.dart';
import 'utils.dart' show snackBarAlert;
import 'i18n.dart';

// Conditional import
import 'non_web_utils.dart' if (dart.library.html) 'web_utils.dart';

class WebdavPage extends StatefulWidget {
  final String currentMessages;
  final Function(String) onRefresh;
  final Future<void> Function() onConfigRestored;
  const WebdavPage({
    super.key,
    required this.currentMessages,
    required this.onRefresh,
    required this.onConfigRestored,
  });
  @override
  WebdavPageState createState() => WebdavPageState();
}

class WebdavPageState extends State<WebdavPage> {
  TextEditingController urlController = TextEditingController();
  TextEditingController usernameController = TextEditingController();
  TextEditingController passwordController = TextEditingController();
  TextEditingController nameController = TextEditingController();
  double progress = 0;
  bool _busy = false;
  List<List<String>> messageRecords = [];

  Future<void> _runRemote(String failureKey,
      Future<void> Function(WebdavBackupStore) action) async {
    if (_busy || !mounted) return;
    setState(() {
      _busy = true;
      progress = 0;
    });
    WebdavBackupStore? store;
    try {
      store = WebdavBackupStore(
          urlController.text, usernameController.text, passwordController.text);
      await action(store);
    } catch (error) {
      if (mounted) {
        snackBarAlert(
            context, '${I18n.t(failureKey)} ${webdavErrorMessage(error)}');
      }
    } finally {
      store?.close();
      if (mounted) setState(() => _busy = false);
    }
  }

  void _updateProgress(int count, int total) {
    if (!mounted) return;
    setState(() =>
        progress = total > 0 ? (count / total).clamp(0.0, 1.0).toDouble() : 0);
  }

  Future<void> testWebdav() => _runRemote('ping_failed', (store) async {
        await store.testConnection();
        if (mounted) snackBarAlert(context, I18n.t('ping_ok'));
      });

  Future<void> backupCurrent(String name) =>
      _runRemote('backup_failed', (store) async {
        await store.write(name, await convertToJson(),
            onProgress: _updateProgress);
        if (!mounted) return;
        snackBarAlert(context, I18n.t('backup_ok'));
        await _readRecords(store);
      });

  Future<void> loadItem(int index) =>
      _runRemote('restore_failed', (store) async {
        final record = List<String>.of(messageRecords[index]);
        final loadedMessage =
            await store.read(record[1], onProgress: _updateProgress);
        final decoded = jsonDecode(loadedMessage);
        if (decoded is! Map<String, dynamic> && decoded is! List) {
          throw const FormatException('Invalid backup');
        }
        if (!mounted) return;
        final action = await showDialog<String>(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: Text(record[0]),
                content: SingleChildScrollView(
                  child: Text(I18n.t('webdav_backup_description')),
                ),
                actions: <Widget>[
                  // 取消
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: Text(I18n.t('cancel')),
                  ),
                  // 覆盖
                  TextButton(
                      onPressed: () => Navigator.of(context).pop('overwrite'),
                      child: Text(I18n.t('overwrite'))),
                  // 恢复
                  TextButton(
                      onPressed: () => Navigator.of(context).pop('restore'),
                      child: Text(I18n.t('file_restore')))
                ],
              );
            });
        if (!mounted) return;
        if (action == 'overwrite') {
          await store.write(record[1], await convertToJson(),
              onProgress: _updateProgress);
          if (!mounted) return;
          snackBarAlert(context, I18n.t('backup_ok'));
          await _readRecords(store);
        } else if (action == 'restore') {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(I18n.t('confirm_restore')),
              content: Text(I18n.t('restore_confirm_msg')),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(I18n.t('cancel'))),
                TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: Text(I18n.t('confirm'))),
              ],
            ),
          );
          if (confirmed != true || !mounted) return;
          if (decoded is Map<String, dynamic>) {
            await restoreFromJson(loadedMessage);
            if (!mounted) return;
            await widget.onConfigRestored();
          } else {
            // Older remote files may contain only a conversation.
            widget.onRefresh(loadedMessage);
            if (mounted) {
              Navigator.of(context).popUntil((route) => route.isFirst);
            }
          }
        }
      });

  Future<void> freshList() => _runRemote('refresh_failed', _readRecords);

  Future<void> _readRecords(WebdavBackupStore store) async {
    final list = await store.listBackups();
    List<List<String>> records = [];
    for (var item in list) {
      if (item.name?.toLowerCase().endsWith(".json") ?? false) {
        final timestamp =
            int.tryParse(item.name!.substring(0, item.name!.length - 5));
        if (timestamp != null && timestamp.abs() <= 8640000000000000) {
          DateTime t = DateTime.fromMillisecondsSinceEpoch(timestamp);
          const weekday = ["", "一", "二", "三", "四", "五", "六", "日"];
          var result = "${t.year}年${t.month}月${t.day}日 星期${weekday[t.weekday]} "
              "${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}"
              ":${t.second.toString().padLeft(2, '0')}";
          records.add([result, item.name!, ""]);
        } else {
          records.add([item.name!, item.name!, '']);
        }
      }
    }
    records.sort((a, b) => b[1].compareTo(a[1]));
    if (!mounted) return;
    setState(() {
      messageRecords = records;
    });
  }

  @override
  void initState() {
    super.initState();
    getWebdav().then((webdav) {
      if (!mounted || webdav.length < 3) return;
      if (webdav[0].isNotEmpty) {
        setState(() {
          urlController.text = webdav[0];
          usernameController.text = webdav[1];
          passwordController.text = webdav[2];
        });
      }
    });
  }

  @override
  void dispose() {
    urlController.dispose();
    usernameController.dispose();
    passwordController.dispose();
    nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(I18n.t('backup_config')),
        actions: [
          IconButton(
              icon: const Icon(Icons.save),
              onPressed: () async {
                await setWebdav(urlController.text.trim(),
                    usernameController.text.trim(), passwordController.text);
                if (mounted) {
                  Navigator.of(context).pop();
                }
              }),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: <Widget>[
            // 本地备份
            ListTile(
              title: Text(I18n.t('local_backup_restore'),
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey)),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  child: Text(I18n.t('download_config')),
                  onPressed: () async {
                    String j = await convertToJson();
                    if (await writeFile(j)) {
                      snackBarAlert(context, I18n.t('download_success'));
                    } else {
                      snackBarAlert(context, I18n.t('download_failed'));
                    }
                  },
                ),
                ElevatedButton(
                  child: Text(I18n.t('file_restore')),
                  onPressed: () async {
                    try {
                      String? j = await pickFile();
                      if (j != null) {
                        bool? confirm = await showDialog<bool>(
                          context: context,
                          builder: (BuildContext context) {
                            return AlertDialog(
                              title: Text(I18n.t('confirm_restore')),
                              content: Text(I18n.t('restore_confirm_msg')),
                              actions: <Widget>[
                                TextButton(
                                  child: Text(I18n.t('cancel')),
                                  onPressed: () {
                                    Navigator.of(context).pop(false);
                                  },
                                ),
                                TextButton(
                                  child: Text(I18n.t('confirm')),
                                  onPressed: () {
                                    Navigator.of(context).pop(true);
                                  },
                                ),
                              ],
                            );
                          },
                        );

                        if (confirm != true) {
                          return;
                        }
                        await restoreFromJson(j);
                        if (!mounted) return;
                        await showDialog<void>(
                          context: context,
                          barrierDismissible: false,
                          builder: (BuildContext context) {
                            return AlertDialog(
                              title: Text(I18n.t('restore_success')),
                              actions: <Widget>[
                                TextButton(
                                  child: Text(I18n.t('confirm')),
                                  onPressed: () => Navigator.of(context).pop(),
                                ),
                              ],
                            );
                          },
                        );
                        if (!mounted) return;
                        await widget.onConfigRestored();
                      } else {
                        snackBarAlert(context, I18n.t('no_file_selected'));
                      }
                    } catch (e) {
                      debugPrint('Failed to restore backup: $e');
                      if (mounted) {
                        snackBarAlert(context, I18n.t('restore_failed'));
                      }
                    }
                  },
                ),
              ],
            ),
            const Divider(),
            // WebDAV 备份
            ListTile(
              title: Text(I18n.t('webdav_backup_restore'),
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: TextField(
                controller: urlController,
                enabled: !_busy,
                decoration: const InputDecoration(
                  labelText: 'URL',
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: TextField(
                controller: usernameController,
                enabled: !_busy,
                decoration: InputDecoration(
                  labelText: I18n.t('username'),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: TextField(
                controller: passwordController,
                enabled: !_busy,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: I18n.t('password'),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              ElevatedButton(
                  onPressed: _busy ? null : testWebdav,
                  child: Text(I18n.t('test'))),
              ElevatedButton(
                onPressed: _busy ? null : freshList,
                child: Text(I18n.t('refresh')),
              ),
              ElevatedButton(
                onPressed: _busy
                    ? null
                    : () async {
                        int timestamp = DateTime.now().millisecondsSinceEpoch;
                        await backupCurrent("$timestamp.json");
                      },
                child: Text(I18n.t('backup')),
              ),
            ]),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: progress,
              minHeight: 2,
              semanticsLabel: 'Linear progress indicator',
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(12.0),
                ),
                child: messageRecords.isEmpty
                    ? Center(child: Text(I18n.t('no_records')))
                    : ListView.builder(
                        itemCount: messageRecords.length,
                        itemBuilder: (BuildContext context, int index) {
                          return Card(
                              child: ListTile(
                            title: Text(messageRecords[index][0]),
                            onTap: _busy ? null : () => loadItem(index),
                          ));
                        },
                      ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
