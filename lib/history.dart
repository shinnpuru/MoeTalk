import 'package:flutter/material.dart';
import 'openai.dart' show completion;
import 'utils.dart' show snackBarAlert, Config;

Future<String?> namingHistory(BuildContext context,String timeStr,Config config,
                              String stuName, List<List<String>> msg) async {
  return showDialog(context: context, builder: (context) {
    final TextEditingController controller = TextEditingController(text: timeStr);
    return AlertDialog(
      title: const Text('命名历史'),
      content: TextField(
        maxLines: null,
        minLines: 1,
        controller: controller,
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () async {
            msg.add(["user","system instruction:暂停角色扮演，根据上下文，以$stuName的口吻用一句话总结该对话。"]);
            String result = "";
            for (var m in msg) {
              debugPrint("${m[0]}: ${m[1]}");
            }
            debugPrint("model: ${config.model}");
            controller.text = "生成中...";
            await completion(config, msg, (chunk){
              result += chunk;
              controller.text = result;
            }, (){
              snackBarAlert(context, "完成");
            }, (e){
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text("Error"),
                  content: Text(e.toString()),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: const Text('确定'),
                    ),
                  ],
                ),
              );
            });
          },
          child: const Text('AI'),
        ),
        TextButton(
          onPressed: () {
            if (controller.text.isEmpty) {
              Navigator.of(context).pop();
            } else {
              Navigator.of(context).pop(controller.text);
            }
          },
          child: const Text('确定'),
        ),
      ],
    );
  });
}