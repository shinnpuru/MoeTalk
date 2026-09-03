import 'package:flutter/material.dart';

import 'audio_cpp_client.dart';
import 'i18n.dart';
import 'storage.dart';
import 'utils.dart';

class VitsConfigPage extends StatefulWidget {
  final VitsConfig vitsConfig;

  const VitsConfigPage({super.key, required this.vitsConfig});

  @override
  State<VitsConfigPage> createState() => _VitsConfigPageState();
}

class _VitsConfigPageState extends State<VitsConfigPage> {
  late final TextEditingController _apiTokenController;
  late final TextEditingController _audioCppBaseUrlController;
  late final TextEditingController _audioCppModelController;
  late TtsBackend _backend;
  late String _language;
  bool _obscureToken = true;
  bool _isTestingAudioCpp = false;

  @override
  void initState() {
    super.initState();
    _apiTokenController = TextEditingController(
      text: widget.vitsConfig.apiToken ?? '',
    );
    _audioCppBaseUrlController = TextEditingController(
      text: widget.vitsConfig.audioCppBaseUrl,
    );
    _audioCppModelController = TextEditingController(
      text: widget.vitsConfig.audioCppModel,
    );
    _backend = widget.vitsConfig.backend;
    _language = const ['Auto', 'English', 'Chinese']
            .contains(widget.vitsConfig.language)
        ? widget.vitsConfig.language
        : 'Auto';
  }

  @override
  void dispose() {
    _apiTokenController.dispose();
    _audioCppBaseUrlController.dispose();
    _audioCppModelController.dispose();
    super.dispose();
  }

  Future<void> _testAudioCppConnection() async {
    FocusScope.of(context).unfocus();
    setState(() => _isTestingAudioCpp = true);
    try {
      final client = AudioCppClient(
        baseUrl: _audioCppBaseUrlController.text,
      );
      await client.checkHealth();
      final models = await client.listModels();
      if (!mounted) return;
      if (_audioCppModelController.text.trim().isEmpty && models.isNotEmpty) {
        _audioCppModelController.text = models.first;
      }
      final modelSummary =
          models.isEmpty ? I18n.t('audio_cpp_no_models') : models.join(', ');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('${I18n.t('audio_cpp_connected')}: $modelSummary')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('${I18n.t('audio_cpp_connect_failed')}: $error')),
      );
    } finally {
      if (mounted) setState(() => _isTestingAudioCpp = false);
    }
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
              await setVitsConfig(VitsConfig(
                backend: _backend,
                apiToken: _apiTokenController.text.trim(),
                language: _language,
                audioCppBaseUrl: _audioCppBaseUrlController.text.trim(),
                audioCppModel: _audioCppModelController.text.trim(),
              ));
              if (!context.mounted) return;
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<TtsBackend>(
            key: ValueKey(_backend),
            initialValue: _backend,
            decoration: InputDecoration(labelText: I18n.t('tts_backend')),
            items: const [
              DropdownMenuItem(
                value: TtsBackend.civitai,
                child: Text('Civitai'),
              ),
              DropdownMenuItem(
                value: TtsBackend.audioCpp,
                child: Text('audio.cpp'),
              ),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _backend = value);
            },
          ),
          const SizedBox(height: 20),
          if (_backend == TtsBackend.civitai) ...[
            TextField(
              controller: _apiTokenController,
              obscureText: _obscureToken,
              decoration: InputDecoration(
                labelText: I18n.t('civitai_api_token'),
                helperText: I18n.t('tts_token_hint'),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureToken ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: () {
                    setState(() => _obscureToken = !_obscureToken);
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
          if (_backend == TtsBackend.audioCpp) ...[
            TextField(
              controller: _audioCppBaseUrlController,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                labelText: I18n.t('audio_cpp_server'),
                helperText: I18n.t('audio_cpp_server_hint'),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _audioCppModelController,
              decoration: InputDecoration(
                labelText: I18n.t('audio_cpp_model'),
                helperText: I18n.t('audio_cpp_model_hint'),
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.tonalIcon(
                onPressed: _isTestingAudioCpp ? null : _testAudioCppConnection,
                icon: _isTestingAudioCpp
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.wifi_tethering),
                label: Text(I18n.t('audio_cpp_test_connection')),
              ),
            ),
            const SizedBox(height: 20),
          ],
          DropdownButtonFormField<String>(
            initialValue: _language,
            decoration: InputDecoration(labelText: I18n.t('tts_language')),
            items: const [
              DropdownMenuItem(value: 'Auto', child: Text('Auto')),
              DropdownMenuItem(value: 'English', child: Text('English')),
              DropdownMenuItem(value: 'Chinese', child: Text('Chinese')),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() => _language = value);
              }
            },
          ),
        ],
      ),
    );
  }
}
