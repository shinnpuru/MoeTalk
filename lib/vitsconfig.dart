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
      final model = await _discoverAudioCppModel();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${I18n.t('audio_cpp_connected')}: $model'),
        ),
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

  Future<String> _discoverAudioCppModel() async {
    final client = AudioCppClient(baseUrl: _audioCppBaseUrlController.text);
    await client.checkHealth();
    final models = await client.listModels();
    if (models.isEmpty) {
      throw AudioCppException(I18n.t('audio_cpp_no_models'));
    }
    final model = models.first;
    _audioCppModelController.text = model;
    return model;
  }

  Future<void> _saveConfig() async {
    if (_backend == TtsBackend.audioCpp) {
      setState(() => _isTestingAudioCpp = true);
      try {
        await _discoverAudioCppModel();
      } catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${I18n.t('audio_cpp_connect_failed')}: $error'),
          ),
        );
        return;
      } finally {
        if (mounted) setState(() => _isTestingAudioCpp = false);
      }
    }

    await setVitsConfig(VitsConfig(
      backend: _backend,
      apiToken: _apiTokenController.text.trim(),
      language: 'Auto',
      audioCppBaseUrl: _audioCppBaseUrlController.text.trim(),
      audioCppModel: _audioCppModelController.text.trim(),
    ));
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(I18n.t('voice_config')),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _isTestingAudioCpp ? null : _saveConfig,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ListTile(
                title: Text(
                  I18n.t('backend_type'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SegmentedButton<TtsBackend>(
                  segments: const [
                    ButtonSegment(
                      value: TtsBackend.civitai,
                      label: Text('Civitai'),
                    ),
                    ButtonSegment(
                      value: TtsBackend.audioCpp,
                      label: Text('audio.cpp'),
                    ),
                  ],
                  selected: {_backend},
                  onSelectionChanged: (selection) {
                    setState(() => _backend = selection.first);
                  },
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                title: Text(
                  I18n.t('base_config'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_backend == TtsBackend.civitai)
                      TextField(
                        controller: _apiTokenController,
                        obscureText: _obscureToken,
                        decoration: InputDecoration(
                          labelText: I18n.t('civitai_api_token'),
                          helperText: I18n.t('tts_token_hint'),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureToken
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                            onPressed: () {
                              setState(
                                () => _obscureToken = !_obscureToken,
                              );
                            },
                          ),
                        ),
                      )
                    else ...[
                      TextField(
                        controller: _audioCppBaseUrlController,
                        keyboardType: TextInputType.url,
                        decoration: InputDecoration(
                          labelText: I18n.t('audio_cpp_server'),
                          helperText: I18n.t('audio_cpp_server_hint'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.tonalIcon(
                        onPressed:
                            _isTestingAudioCpp ? null : _testAudioCppConnection,
                        icon: _isTestingAudioCpp
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.wifi_tethering),
                        label: Text(I18n.t('test_connection')),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
