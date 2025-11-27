import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
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
  TextEditingController drawCharPromptController = TextEditingController();
  TextEditingController vitsPromptController = TextEditingController();

  @override
  void initState() {
    super.initState();
    getPrompt().then((String value) {
      setState(() {
        controller.text = value;
      });
    });
    getAvatar().then((String value) {
      setState(() {
        studentAvatarController.text = value;
      });
    });
    getStudentName().then((String value) {
      setState(() {
        studentNameController.text = value;
      });
    });
    getOriginalMsg().then((String value) {
      setState(() {
        originMsgController.text = value;
      });
    });
    getDrawCharPrompt().then((String value) {
      setState(() {
        drawCharPromptController.text = value;
      });
    });
    getVitsPrompt().then((String value) {
      setState(() {
        vitsPromptController.text = value;
      });
    });
  }

  Future<void> _pickAvatar() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['png'],
    );


    if (result != null && result.files.single.bytes != null) {
      String base64Image = base64Encode(result.files.single.bytes!);
      final base64String = 'data:image/png;base64,${base64Image}';
      setState(() {
        studentAvatarController.text = base64String;
      });
    }
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
        title: const Text('角色编辑器'),
        actions: [
          // 初始化
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              controller.text = await getPrompt(isDefault: true);
              studentNameController.text = await getStudentName(isDefault: true);
              originMsgController.text = await getOriginalMsg(isDefault: true);
              studentAvatarController.text = await getAvatar(isDefault: true);
              drawCharPromptController.text = await getDrawCharPrompt(isDefault: true);
              vitsPromptController.text = await getVitsPrompt(isDefault: true);
              setState(() {});
            },
          ),
          // 保存
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: () {
              setPrompt(controller.text);
              setStudentName(studentNameController.text);
              setOriginalMsg(originMsgController.text);
              setAvatar(studentAvatarController.text);
              setDrawCharPrompt(drawCharPromptController.text);
              setVitsPrompt(vitsPromptController.text);
              Navigator.pop(context);
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(8.0),
        children: <Widget>[
          const ListTile(
            title: Text('角色头像（点击更换）'),
          ),
          GestureDetector(
            onTap: _pickAvatar,
            child: Center(
              child: CircleAvatar(
                radius: 50,
                backgroundImage: studentAvatarController.text.startsWith('http')
                ? NetworkImage(studentAvatarController.text)
                : studentAvatarController.text.startsWith('data:image/')
                  ? MemoryImage(base64Decode(studentAvatarController.text.split(',')[1]))
                  : const AssetImage("assets/avatar.png")
              ),
            ),
          ),
          ListTile(
            title: const Text('角色名'),
            subtitle: Text(
              studentNameController.text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () =>
                _showEditDialog(context, '角色名', studentNameController),
          ),
          ListTile(
            title: const Text('初始对话'),
            subtitle: Text(
              originMsgController.text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () => _showEditDialog(context, '初始对话', originMsgController,
                multiLine: true),
          ),
          ListTile(
            title: const Text('设定提示词'),
            subtitle: Text(
              controller.text,
              maxLines: null,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontFamily: "Courier"),
            ),
            onTap: () =>
                _showEditDialog(context, '设定提示词', controller, multiLine: true),
          ),
          ListTile(
            title: const Text('绘画提示词'),
            subtitle: Text(
              drawCharPromptController.text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () => _showEditDialog(context, '绘画提示词', drawCharPromptController,
                multiLine: true),
          ),
          ListTile(
            title: const Text('语音参考'),
            subtitle: Text(
              vitsPromptController.text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () => _showEditDialog(context, '语音参考', vitsPromptController,
                multiLine: true),
          ),
        ],
      ),
    );
  }
}
