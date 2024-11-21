import 'package:flutter/material.dart';
import 'storage.dart';

class PromptEditor extends StatefulWidget {
  const PromptEditor({super.key});

  @override
  PromptEditorState createState() => PromptEditorState();
}

class PromptEditorState extends State<PromptEditor> {
  TextEditingController controller = TextEditingController();
  TextEditingController studentNameController = TextEditingController();
  TextEditingController originMsgController = TextEditingController();
  TextEditingController studentAvatarController = TextEditingController();

  @override
  void initState() {
    super.initState();
    getPrompt(isRaw: true).then((String value) {
      controller.text = value;
    });
    getAvatar().then((String value) {
      studentAvatarController.text = value;
    });
    getStudentName().then((String value) {
      studentNameController.text = value;
    });
    getOriginalMsg().then((String value) {
      originMsgController.text = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Prompt Editor'),
      ),
      body:  Column(
        children: <Widget>[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: () async{
                  controller.text = await getPrompt(isDefault: true, isRaw: true);
                  studentNameController.text = await getStudentName(isDefault: true);
                  originMsgController.text = await getOriginalMsg(isDefault: true);
                },
                child: const Text('恢复'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  setPrompt(controller.text);
                  setStudentName(studentNameController.text);
                  setOriginalMsg(originMsgController.text);
                  setAvatar(studentAvatarController.text);
                  Navigator.pop(context);
                },
                child: const Text('保存'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: studentAvatarController,
            decoration: const InputDecoration(
              labelText: 'Student Avatar',
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: studentNameController,
            decoration: const InputDecoration(
              labelText: 'Student Name',
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: originMsgController,
            decoration: const InputDecoration(
              labelText: 'Origin Message',
            ),
          ),
          Expanded(child:
          Padding(padding: const EdgeInsets.all(8.0),
            child: 
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'Prompt（可通过添加prompt_split标记分隔ExternalPrompt）',
                ),
                style: const TextStyle(fontSize: 16,fontFamily: "Courier"),
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
              )
            )
          ),
        ],
      ),
    );
  }
}