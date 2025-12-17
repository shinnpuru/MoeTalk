import 'package:flutter/material.dart';
import 'storage.dart';
import 'msgeditor.dart';
import 'i18n.dart';

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
      if (mounted) setState(() => summaryPrompt.text = value);
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
          title: Text('${I18n.t('edit_title')}$title'),
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
              child: Text(I18n.t('cancel')),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text(I18n.t('confirm')),
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
        title: Text(I18n.t('format_config')),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: () {
              setResponseRegex(responseRegex.text);
              setUserName(userName.text);
              setStatusPrompt(statusPrompt.text);
              setInspirePrompt(inspirePrompt.text);
              setDrawPrompt(drawPrompt.text);
              setEndPrompt(endPrompt.text);
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
            ListTile(
              title: Text(I18n.t('common_prompt'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child:  Column(
                children: [
                  TextField(
                    controller: userName,
                    decoration: InputDecoration(
                      labelText: I18n.t('user_name'),
                    ),
                    style: const TextStyle(fontSize: 16,fontFamily: "Courier"),
                  ),
              ],
              )
            ),
            const SizedBox(height: 8),
            ListTile(
              title: Text(I18n.t('context_template')),
              subtitle: Text(I18n.t('context_template_hint')),
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
              title: Text(I18n.t('output_regex')),
              subtitle: Text(
                responseRegex.text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () => _showEditDialog(context, I18n.t('output_regex'), responseRegex),
            ),
            const SizedBox(height: 16),
            ListTile(
              title: Text(I18n.t('prompt_config'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey)), // Reuse or create new key? prompt_config maps to "提示词配置" in aidrawconfig, maybe fine or create 'feature_prompts'
            ),
            ListTile(
              title: Text(I18n.t('chat_prompt')),
              subtitle: Text(
                endPrompt.text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () => _showEditDialog(context, I18n.t('chat_prompt'), endPrompt, multiLine: true),
            ),
            ListTile(
              title: Text(I18n.t('draw_prompt')),
              subtitle: Text(
                drawPrompt.text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () => _showEditDialog(context, I18n.t('draw_prompt'), drawPrompt, multiLine: true),
            ),
            ListTile(
              title: Text(I18n.t('status_prompt')),
              subtitle: Text(
                statusPrompt.text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () => _showEditDialog(context, I18n.t('status_prompt'), statusPrompt, multiLine: true),
            ),
            ListTile(
              title: Text(I18n.t('inspire_prompt')),
              subtitle: Text(
                inspirePrompt.text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () => _showEditDialog(context, I18n.t('inspire_prompt'), inspirePrompt, multiLine: true),
            ),
            ListTile(
              title: Text(I18n.t('summary_prompt')),
              subtitle: Text(
                summaryPrompt.text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () => _showEditDialog(context, I18n.t('summary_prompt'), summaryPrompt, multiLine: true),
            ),
          ],
        ),
      ),
    );
  }
}
