import 'package:flutter/material.dart';
import 'storage.dart';
import 'utils.dart';
import 'i18n.dart';
import 'vits.dart';

class VitsConfigPage extends StatefulWidget {
  final VitsConfig vitsConfig;

  const VitsConfigPage({super.key, required this.vitsConfig});

  @override
  State<VitsConfigPage> createState() => _VitsConfigPageState();
}

class _VitsConfigPageState extends State<VitsConfigPage> {
  late TextEditingController _apiController;
  late TextEditingController _apiKeyController;
  late TextEditingController _voiceIdController;
  late TextEditingController _languageController;
  late TextEditingController _audioFormatController;

  @override
  void initState() {
    super.initState();
    _apiController = TextEditingController();
    _apiKeyController = TextEditingController();
    _voiceIdController = TextEditingController();
    _languageController = TextEditingController();
    _audioFormatController = TextEditingController();
    getVitsUrl().then((value) {
      if (mounted) {
        _apiController.text = value ?? '';
      }
    });

    final vitsConfig = widget.vitsConfig;
    _apiKeyController.text = vitsConfig.apiKey ?? '';
    _voiceIdController.text = vitsConfig.voiceId ?? 'eve';
    _languageController.text = vitsConfig.language ?? 'zh';
    _audioFormatController.text = vitsConfig.audioFormat ?? 'mp3';
  }

  @override
  void dispose() {
    _apiController.dispose();
    _apiKeyController.dispose();
    _voiceIdController.dispose();
    _languageController.dispose();
    _audioFormatController.dispose();
    super.dispose();
  }

  Future<void> _persistConfig() async {
    VitsConfig updatedConfig = VitsConfig(
      apiKey: _apiKeyController.text.trim(),
      voiceId: _voiceIdController.text.trim(),
      language: _languageController.text.trim(),
      audioFormat: _audioFormatController.text.trim(),
    );
    await setVitsConfig(updatedConfig);
    await setVitsUrl(_apiController.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(I18n.t('voice_config')),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: () async {
              await _persistConfig();
              if (mounted) {
                Navigator.of(context).pop();
              }
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            ListTile(
              title: Text(I18n.t('base_config'),
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child:  Column(
                children: [
                  TextField(
                    controller: _apiController,
                    decoration: InputDecoration(labelText: I18n.t('api_url')),
                    minLines: 1,
                    maxLines: 3,
                  ),
                ]
              )
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child:  Column(
                children: [
                  TextField(
                    controller: _apiKeyController,
                    decoration: InputDecoration(labelText: I18n.t('api_key')),
                    minLines: 1,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _voiceIdController,
                    decoration: InputDecoration(labelText: I18n.t('voice_id')),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _languageController,
                    decoration: InputDecoration(labelText: I18n.t('language')),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _audioFormatController,
                    decoration: InputDecoration(labelText: I18n.t('audio_format')),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () async {
                      await _persistConfig();
                      final String testText = I18n.locale == 'zh'
                          ? '你好，这是语音测试。'
                          : 'Hello, this is a voice test.';
                      await queryAndPlayAudio(context, testText);
                    },
                    icon: const Icon(Icons.play_arrow),
                    label: Text(I18n.t('test')),
                  ),
                ]
              )
            )
          ],
        ),
      ),
    );
  }
}