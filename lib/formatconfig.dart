import 'package:flutter/material.dart';
import 'storage.dart';

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
                controller: userName,
                decoration: const InputDecoration(
                  labelText: '用户名称',
                ),
                style: const TextStyle(fontSize: 16,fontFamily: "Courier"),
              ),
            Text("提示：用户名称在提示词中可用{{user}}代替，角色名称可用{{char}}代替。"),
            const SizedBox(height: 16),
            TextField(
                controller: startPrompt,
                decoration: const InputDecoration(
                  labelText: '开始提示词',
                ),
                minLines: 3,
                maxLines: 3,
                style: const TextStyle(fontSize: 16,fontFamily: "Courier"),
              ),
            TextField(
                controller: endPrompt,
                decoration: const InputDecoration(
                  labelText: '结束提示词',
                ),
                minLines: 3,
                maxLines: 3,
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
            const SizedBox(height: 16),
            TextField(
                controller: responseRegex,
                decoration: const InputDecoration(
                  labelText: '输出正则过滤',
                ),
                style: const TextStyle(fontSize: 16,fontFamily: "Courier"),
              ),
          ],
        ),
      ),
    );
  }
}