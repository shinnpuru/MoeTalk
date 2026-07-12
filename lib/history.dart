import 'package:flutter/material.dart';
import 'storage.dart';
import 'openai.dart' show completion;
import 'utils.dart' show snackBarAlert, Config;
import 'i18n.dart';

Future<String?> namingHistory(BuildContext context,String timeStr,Config config, List<List<String>> msg) async {
  return showDialog(context: context, builder: (context) {
    final TextEditingController controller = TextEditingController(text: timeStr);
    return AlertDialog(
      title: Text(I18n.t('naming_history')),
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
          child: Text(I18n.t('cancel')),
        ),
        TextButton(
          onPressed: () async {
            String result = "";
            for (var m in msg) {
              debugPrint("${m[0]}: ${m[1]}");
            }
            debugPrint("model: ${config.model}");
            controller.text = I18n.t('generating');
            await completion(config, msg, (chunk) async {
              result += chunk;
              controller.text = result.replaceAll(RegExp(await getResponseRegex()), '');
            }, (){
              snackBarAlert(context, I18n.t('finish'));
            }, (e){
              snackBarAlert(context, "${I18n.t('error')}: $e");
            });
          },
          child: Text(I18n.t('ai')),
        ),
        TextButton(
          onPressed: () {
            if (controller.text.isEmpty) {
              Navigator.of(context).pop();
            } else {
              Navigator.of(context).pop(controller.text);
            }
          },
          child: Text(I18n.t('confirm')),
        ),
      ],
    );
  });
}