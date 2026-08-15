import 'package:flutter/material.dart';

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
  late String _language;
  bool _obscureToken = true;

  @override
  void initState() {
    super.initState();
    _apiTokenController = TextEditingController(
      text: widget.vitsConfig.apiToken ?? '',
    );
    _language = const ['Auto', 'English', 'Chinese']
            .contains(widget.vitsConfig.language)
        ? widget.vitsConfig.language
        : 'Auto';
  }

  @override
  void dispose() {
    _apiTokenController.dispose();
    super.dispose();
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
                apiToken: _apiTokenController.text.trim(),
                language: _language,
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
          DropdownButtonFormField<String>(
            value: _language,
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
