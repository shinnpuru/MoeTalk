import 'package:flutter/material.dart';
import 'storage.dart';
import 'msgeditor.dart';

class FormatConfigPage extends StatefulWidget {
  const FormatConfigPage({super.key});

  @override
  State<FormatConfigPage> createState() => _FormatConfigPageState();
}

class _FormatConfigPageState extends State<FormatConfigPage> {
  final TextEditingController responseRegex = TextEditingController();
  final TextEditingController userName = TextEditingController();
  final TextEditingController statusPrompt = TextEditingController();
  final TextEditingController inspirePrompt = TextEditingController();
  final TextEditingController drawPrompt = TextEditingController();
  final TextEditingController endPrompt = TextEditingController();
  final TextEditingController summaryPrompt = TextEditingController();

  @override
  void initState() {
    super.initState();
    getResponseRegex().then((value) {
      if (mounted) setState(() => responseRegex.text = value);
    });
    getUserName().then((value) {
      if (mounted) setState(() => userName.text = value);
    });
    getStatusPrompt().then((value) {
      if (mounted) setState(() => statusPrompt.text = value);
    });
    getInspirePrompt().then((value) {
      if (mounted) setState(() => inspirePrompt.text = value);
    });
    getDrawPrompt().then((value) {
      if (mounted) setState(() => drawPrompt.text = value);
    });
    getEndPrompt().then((value) {
      if (mounted) setState(() => endPrompt.text = value);
    });
    getSummaryPrompt().then((value) {
      if (mounted) setState(() => endPrompt.text = value);
    });
  }

  @override
  void dispose() {
    responseRegex.dispose();
    userName.dispose();
    statusPrompt.dispose();
    inspirePrompt.dispose();
    drawPrompt.dispose();
    endPrompt.dispose();
    summaryPrompt.dispose();
    super.dispose();
  }

  Future<void> _showEditDialog(BuildContext context, String title,
      TextEditingController controller, {bool multiLine = false}) async {
    final TextEditingController dialogController =
        TextEditingController(text: controller.text);
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('编辑 $title'),
          content: TextField(
            controller: dialogController,
            maxLines: multiLine ? 5 : 1,
            autofocus: true,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              labelText: title,
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('取消'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('确定'),
              onPressed: () {
                setState(() {
                  controller.text = dialogController.text;
                });
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('格式配置'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: () {
              setResponseRegex(responseRegex.text);
              setUserName(userName.text);
              setStatusPrompt(statusPrompt.text);
              setInspirePrompt(inspirePrompt.text);
              setDrawPrompt(drawPrompt.text);
              setEndPrompt(drawPrompt.text);
              setSummaryPrompt(summaryPrompt.text);
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            const SizedBox(height: 16),
            const ListTile(
              title: Text('通用提示词', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child:  Column(
                children: [
                  TextField(
                    controller: userName,
                    decoration: const InputDecoration(
                      labelText: '用户名称',
                    ),
                    style: const TextStyle(fontSize: 16,fontFamily: "Courier"),
                  ),
              ],
              )
            ),
            const SizedBox(height: 8),
            ListTile(
              title: const Text('上下文模板'),
              subtitle: const Text("提示：用户名称在提示词中可用{{user}}代替，角色名称可用{{char}}代替。"),
              onTap: () async {
                var msgs = await getContextTemplate();
                if (context.mounted) {
                  var res = await Navigator.push(context, MaterialPageRoute(builder: (context) => MsgEditor(msgs: msgs)));
                  if (res != null) {
                    await setContextTemplate(res);
                  }
                }
              },
            ),
            ListTile(
              title: const Text('输出正则过滤'),
              subtitle: Text(
                responseRegex.text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () => _showEditDialog(context, '输出正则过滤', responseRegex),
            ),
            const SizedBox(height: 16),
            const ListTile(
              title: Text('功能提示词', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey)),
            ),
            ListTile(
              title: const Text('聊天提示词'),
              subtitle: Text(
                endPrompt.text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () => _showEditDialog(context, '聊天提示词', endPrompt, multiLine: true),
            ),
            ListTile(
              title: const Text('绘画提示词'),
              subtitle: Text(
                drawPrompt.text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () => _showEditDialog(context, '绘画提示词', drawPrompt, multiLine: true),
            ),
            ListTile(
              title: const Text('状态提示词'),
              subtitle: Text(
                statusPrompt.text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () => _showEditDialog(context, '状态提示词', statusPrompt, multiLine: true),
            ),
            ListTile(
              title: const Text('灵感提示词'),
              subtitle: Text(
                inspirePrompt.text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () => _showEditDialog(context, '灵感提示词', inspirePrompt, multiLine: true),
            ),
            ListTile(
              title: const Text('总结提示词'),
              subtitle: Text(
                summaryPrompt.text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () => _showEditDialog(context, '总结提示词', summaryPrompt, multiLine: true),
            ),
          ],
        ),
      ),
    );
  }
}