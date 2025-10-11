// ignore_for_file: use_build_context_synchronously

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:webdav_client/webdav_client.dart';
import 'storage.dart';
import 'utils.dart' show snackBarAlert;

// Conditional import
import 'non_web_utils.dart'
    if (dart.library.html) 'web_utils.dart';

class WebdavPage extends StatefulWidget {
  final String currentMessages;
  final Function(String) onRefresh;
  const WebdavPage({super.key, required this.currentMessages,required this.onRefresh});
  @override
  WebdavPageState createState() => WebdavPageState();
}

class WebdavPageState extends State<WebdavPage> {
  TextEditingController urlController = TextEditingController();
  TextEditingController usernameController = TextEditingController();
  TextEditingController passwordController = TextEditingController();
  TextEditingController nameController = TextEditingController();
  double progress = 0;
  List<List<String>> messageRecords = [];

  void errDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Error'),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('确定'),
            ),
          ],
        );
      },
    );
  }

  Future<void> testWebdav() async {
    try {
      var client = newClient(urlController.text, user: usernameController.text, password: passwordController.text);
      await client.ping();
      if(!context.mounted) return;
      snackBarAlert(context, "Ping OK");
    } catch (e) {
      errDialog(e.toString());
    }
  }

  Future<void> backupCurrent(String name) async {
    try {
      var client = newClient(urlController.text, user: usernameController.text, password: passwordController.text);
      Uint8List data = utf8.encode(await convertToJson());
      setState(() {
        progress = 0;
      });
      await client.write(name, data, onProgress: (count, total) {
        setState(() {
          progress = count / total;
        });
      },);
      if(!context.mounted) return;
      snackBarAlert(context, "Backup OK");
    } catch (e) {
      errDialog(e.toString());
    }
  }

  Future<String> getContent(String name) async {
    var client = newClient(urlController.text, user: usernameController.text, password: passwordController.text);
    setState(() {
      progress = 0;
    });
    List<int> data = await client.read("momotalk/$name", onProgress: (count, total) {
      setState(() {
        progress = count / total;
      });
    });
    return utf8.decode(data);
  }

  Future<void> loadItem(int index) async {
    String loadedMessage = "";
    if (messageRecords[index].length == 3 && messageRecords[index][2].isNotEmpty) {
      loadedMessage = messageRecords[index][2];
    } else{
      loadedMessage = await getContent(messageRecords[index][1]);
      messageRecords[index][2] = loadedMessage;
    }
    showDialog(context: context, builder: 
      (BuildContext context) {
        return AlertDialog(
          title: Text(messageRecords[index][0]),
          content: SingleChildScrollView(
            child: Text(loadedMessage),
          ),
          actions: <Widget>[
            // 取消
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('取消'),
            ),
            // 覆盖
            TextButton(
              onPressed: () async {
                backupCurrent("momotalk/${messageRecords[index][1]}");
                Navigator.of(context).pop();
              }, 
              child: const Text('覆盖')
            ),
            // 恢复
            TextButton(
              onPressed: () {
                widget.onRefresh(loadedMessage);
                Navigator.of(context).popUntil((route) => route.isFirst);
              }, 
              child: const Text('恢复')
            )
          ],
        );
      }
    );
  }
  
  Future<void> freshList() async {
    try {
      var client = newClient(urlController.text, user: usernameController.text, password: passwordController.text);
      client.readDir("momotalk").then((list) {
        List<List<String>> records = [];
        for (var item in list) {
          if (item.name?.endsWith(".json") ?? false) {
            if (int.tryParse(item.name!.replaceAll(".json", ''))!=null) {
              int timestamp = int.parse(item.name!.replaceAll(".json", ''));
                DateTime t = DateTime.fromMillisecondsSinceEpoch(timestamp);
                const weekday = ["", "一", "二", "三", "四", "五", "六", "日"];
                var result =
                  "${t.year}年${t.month}月${t.day}日 星期${weekday[t.weekday]} "
                  "${t.hour.toString().padLeft(2,'0')}:${t.minute.toString().padLeft(2,'0')}"
                  ":${t.second.toString().padLeft(2,'0')}";
                records.add([result,item.name!,""]);
            }
          }
        }
        records.sort((a, b) => b[1].compareTo(a[1]));
        setState(() {
          messageRecords = records;
        });
      });
    } catch (e) {
      errDialog(e.toString());
    }
  }

  @override
  void initState() {
    super.initState();
    getWebdav().then((webdav) {
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('备份配置'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: () async {
                  await setWebdav(urlController.text, usernameController.text, passwordController.text);
                  if(!context.mounted) return;
                  snackBarAlert(context, 'Saved');
                }),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: <Widget>[
            // 本地备份
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  child: const Text('下载配置'),
                  onPressed: () async {
                    String j = await convertToJson();
                    debugPrint(j);
                    if(await writeFile(j)){
                      snackBarAlert(context, "下载成功");
                    } else {
                      snackBarAlert(context, "下载失败");
                    }
                  },
                ),
                ElevatedButton(
                  child: const Text('文件恢复'),
                  onPressed: () async {
                    String? j = await pickFile();
                    if (j != null) {
                      try {
                        debugPrint(j);
                        await restoreFromJson(j);
                        snackBarAlert(context, "恢复成功");
                      } catch (e) {
                        snackBarAlert(context, "恢复失败");
                        return;
                      }
                    } else {
                      snackBarAlert(context, "未选择文件");
                    }
                  },
                ),
              ],
            ),
            const Divider(),
            // WebDAV 备份
            TextField(
              controller: urlController,
              decoration: const InputDecoration(
                labelText: 'URL',
              ),
            ),
            TextField(
              controller: usernameController,
              decoration: const InputDecoration(
                labelText: 'Username',
              ),
            ),
            TextField(
              controller: passwordController,
              decoration: const InputDecoration(
                labelText: 'Password',
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: testWebdav, 
                  child: const Text('测试')),
                ElevatedButton(
                  onPressed: freshList,
                  child: const Text('刷新'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    int timestamp = DateTime.now().millisecondsSinceEpoch;
                    backupCurrent("momotalk/$timestamp.json");
                  },
                  child: const Text('备份'),
                ),
              ]
            ),
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
                child: messageRecords.isEmpty ? const Center(child: Text('无记录')) :
                ListView.builder(
                  itemCount: messageRecords.length,
                  itemBuilder: (BuildContext context, int index) {
                    return Card(
                      child: ListTile(
                        title: Text(messageRecords[index][0]),
                        onTap: () => loadItem(index),
                      )
                    );
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