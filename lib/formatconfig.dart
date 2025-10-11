import 'package:flutter/material.dart';
import 'storage.dart';
import 'utils.dart';

class FormatConfigPage extends StatelessWidget {
  
  const FormatConfigPage({super.key});

  @override
  Widget build(BuildContext context) {
    TextEditingController startPrompt = TextEditingController();
    TextEditingController endPrompt = TextEditingController();
    TextEditingController responseRegex = TextEditingController();
    TextEditingController userName = TextEditingController();
    TextEditingController statusPrompt = TextEditingController();
    getStartPrompt().then((value) {
      startPrompt.text = value;
    });
    getEndPrompt().then((value) {
      endPrompt.text = value;
    });
    getResponseRegex().then((value) {
      responseRegex.text = value;
    });
    getUserName().then((value) {
      userName.text = value;
    });
    getStatusPrompt().then((value) {
      statusPrompt.text = value;
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('格式配置'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: () {
              setStartPrompt(startPrompt.text);
              setEndPrompt(endPrompt.text);
              setResponseRegex(responseRegex.text);
              setUserName(userName.text);
              setStatusPrompt(statusPrompt.text);
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
                controller: startPrompt,
                decoration: const InputDecoration(
                  labelText: '开始系统提示词',
                ),
                minLines: 3,
                maxLines: 3,
                style: const TextStyle(fontSize: 16,fontFamily: "Courier"),
              ),
            TextField(
                controller: endPrompt,
                decoration: const InputDecoration(
                  labelText: '结束系统提示词',
                ),
                minLines: 3,
                maxLines: 3,
                style: const TextStyle(fontSize: 16,fontFamily: "Courier"),
              ),
            const SizedBox(height: 16),
            TextField(
                controller: responseRegex,
                decoration: const InputDecoration(
                  labelText: '删除正则表达式',
                ),
                style: const TextStyle(fontSize: 16,fontFamily: "Courier"),
              ),
            const SizedBox(height: 16),
            TextField(
                controller: userName,
                decoration: const InputDecoration(
                  labelText: '用户名称',
                ),
                style: const TextStyle(fontSize: 16,fontFamily: "Courier"),
              ),
            const SizedBox(height: 16),
            TextField(
                controller: statusPrompt,
                decoration: const InputDecoration(
                  labelText: '状态提示词',
                ),
                minLines: 3,
                maxLines: 3,
                style: const TextStyle(fontSize: 16,fontFamily: "Courier"),
              ),
          ],
        ),
      ),
    );
  }
}