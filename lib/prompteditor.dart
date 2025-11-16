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
  }

  Future<void> _pickAvatar() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['png'],
    );

    if (result != null && result.files.single.path != null) {
      File file = File(result.files.single.path!);
      final bytes = await file.readAsBytes();
      final base64String = 'data:image/png;base64,${base64Encode(bytes)}';
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
              Navigator.pop(context);
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(8.0),
        children: <Widget>[
          const ListTile(
            title: Text('角色头像'),
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
            title: const Text('提示词'),
            subtitle: Text(
              controller.text,
              maxLines: null,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontFamily: "Courier"),
            ),
            onTap: () =>
                _showEditDialog(context, '提示词', controller, multiLine: true),
          ),
        ],
      ),
    );
  }
}