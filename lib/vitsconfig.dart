import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'storage.dart';
import 'utils.dart';
import 'i18n.dart';

class VitsConfigPage extends StatefulWidget {
  final VitsConfig vitsConfig;

  const VitsConfigPage({super.key, required this.vitsConfig});

  @override
  State<VitsConfigPage> createState() => _VitsConfigPageState();
}

class _VitsConfigPageState extends State<VitsConfigPage> {
  final FlutterTts _flutterTts = FlutterTts();
  late TextEditingController _languageController;
  late TextEditingController _voiceNameController;
  late TextEditingController _voiceLocaleController;
  late double _speechRate;
  late double _volume;
  late double _pitch;
  late bool _sharedInstance;
  late bool _focus;
  List<String> _languages = [];
  List<Map<String, String>> _voices = [];
  String? _selectedVoiceKey;

  @override
  void initState() {
    super.initState();
    final vitsConfig = widget.vitsConfig;
    _languageController = TextEditingController(text: vitsConfig.language ?? 'zh-CN');
    _voiceNameController = TextEditingController(text: vitsConfig.voiceName ?? '');
    _voiceLocaleController = TextEditingController(text: vitsConfig.voiceLocale ?? '');
    _speechRate = (vitsConfig.speechRate ?? 0.5).clamp(0.1, 1.0);
    _volume = (vitsConfig.volume ?? 1.0).clamp(0.0, 1.0);
    _pitch = (vitsConfig.pitch ?? 1.0).clamp(0.5, 2.0);
    _sharedInstance = vitsConfig.sharedInstance ?? true;
    _focus = vitsConfig.focus ?? true;

    _loadLanguages();
    _loadVoices();
  }

  @override
  void dispose() {
    _languageController.dispose();
    _voiceNameController.dispose();
    _voiceLocaleController.dispose();
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
              VitsConfig updatedConfig = VitsConfig(
                language: _languageController.text.trim().isEmpty
                    ? 'zh-CN'
                    : _languageController.text.trim(),
                speechRate: _speechRate,
                volume: _volume,
                pitch: _pitch,
                voiceName: _voiceNameController.text.trim(),
                voiceLocale: _voiceLocaleController.text.trim(),
                sharedInstance: _sharedInstance,
                focus: _focus,
              );
              await setVitsConfig(updatedConfig);
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
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                    value: _currentLanguageDropdownValue(),
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: I18n.t('tts_language'),
                    ),
                    items: _languages
                        .map(
                          (lang) => DropdownMenuItem<String>(
                            value: lang,
                            child: Text(lang),
                          ),
                        )
                        .toList(),
                    onChanged: _languages.isEmpty
                        ? null
                        : (value) {
                            if (value == null) return;
                            setState(() {
                              _languageController.text = value;
                            });
                            _autoSelectVoiceByLanguage();
                          },
                  ),
                  if (_languages.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        I18n.t('tts_no_languages'),
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedVoiceKey,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: I18n.t('tts_voice'),
                          ),
                          items: _voices
                              .map(
                                (voice) => DropdownMenuItem<String>(
                                  value: _voiceKey(voice['name']!, voice['locale']!),
                                  child: Text('${voice['name']} (${voice['locale']})'),
                                ),
                              )
                              .toList(),
                          onChanged: _voices.isEmpty
                              ? null
                              : (value) {
                                  if (value == null) return;
                                  final parts = value.split('||');
                                  if (parts.length != 2) return;
                                  setState(() {
                                    _selectedVoiceKey = value;
                                    _voiceNameController.text = parts[0];
                                    _voiceLocaleController.text = parts[1];
                                  });
                                },
                        ),
                      ),
                      IconButton(
                        onPressed: () async {
                          await _loadLanguages();
                          await _loadVoices();
                        },
                        icon: const Icon(Icons.refresh),
                        tooltip: I18n.t('tts_reload_languages_voices'),
                      ),
                    ],
                  ),
                  if (_voices.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        I18n.t('tts_no_voices'),
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              title: Text(I18n.t('tts_params'),
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                children: [
                  _buildSlider(I18n.t('speech_rate'), _speechRate, 0.2, 2.0,
                      (val) => setState(() => _speechRate = val)),
                  _buildSlider(I18n.t('volume'), _volume, 0.0, 1.0,
                      (val) => setState(() => _volume = val)),
                  _buildSlider(I18n.t('pitch'), _pitch, 0.5, 2.0,
                      (val) => setState(() => _pitch = val)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlider(String label, double value, double min, double max,
      ValueChanged<double> onChanged) {
    return Row(
      children: [
        SizedBox(width: 90, child: Text(label)),
        Expanded(
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: 10,
            onChanged: onChanged,
          ),
        ),
        SizedBox(width: 44, child: Text(value.toStringAsFixed(1))),
      ],
    );
  }

  String _voiceKey(String name, String locale) => '$name||$locale';

  String? _currentLanguageDropdownValue() {
    final current = _languageController.text.trim();
    if (_languages.contains(current)) {
      return current;
    }
    return null;
  }

  Future<void> _loadLanguages() async {
    try {
      final dynamic rawLanguages = await _flutterTts.getLanguages;
      final List<String> parsedLanguages = [];

      if (rawLanguages is List) {
        for (final lang in rawLanguages) {
          final text = lang.toString().trim();
          if (text.isNotEmpty) {
            parsedLanguages.add(text);
          }
        }
      }

      parsedLanguages.sort();

      if (!mounted) return;
      setState(() {
        _languages = parsedLanguages.toSet().toList();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _languages = [];
      });
    }
  }

  Future<void> _loadVoices() async {
    try {
      final dynamic rawVoices = await _flutterTts.getVoices;
      final List<Map<String, String>> parsedVoices = [];

      if (rawVoices is List) {
        for (final voice in rawVoices) {
          if (voice is Map) {
            final name = voice['name']?.toString() ?? '';
            final locale = voice['locale']?.toString() ?? '';
            if (name.isNotEmpty && locale.isNotEmpty) {
              parsedVoices.add({'name': name, 'locale': locale});
            }
          }
        }
      }

      parsedVoices.sort((a, b) {
        final l = (a['locale']!).compareTo(b['locale']!);
        if (l != 0) return l;
        return (a['name']!).compareTo(b['name']!);
      });

      if (!mounted) return;
      setState(() {
        _voices = parsedVoices;
      });

      _autoSelectVoiceByLanguage();
      _syncSelectedVoiceKey();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _voices = [];
      });
    }
  }

  void _syncSelectedVoiceKey() {
    final name = _voiceNameController.text.trim();
    final locale = _voiceLocaleController.text.trim();
    if (name.isEmpty || locale.isEmpty) {
      if (mounted) {
        setState(() {
          _selectedVoiceKey = null;
        });
      }
      return;
    }

    final key = _voiceKey(name, locale);
    final exists = _voices.any((v) => _voiceKey(v['name']!, v['locale']!) == key);
    if (!mounted) return;
    setState(() {
      _selectedVoiceKey = exists ? key : null;
    });
  }

  void _autoSelectVoiceByLanguage() {
    if (_voices.isEmpty) return;

    final language = _languageController.text.trim().toLowerCase();
    if (language.isEmpty) return;

    Map<String, String>? bestMatch;

    for (final voice in _voices) {
      final locale = (voice['locale'] ?? '').toLowerCase();
      if (locale == language) {
        bestMatch = voice;
        break;
      }
    }

    bestMatch ??= _voices.cast<Map<String, String>?>().firstWhere(
          (voice) => (voice?['locale'] ?? '').toLowerCase().startsWith(language.split('-').first),
          orElse: () => null,
        );

    if (bestMatch == null) return;

    if (!mounted) return;
    setState(() {
      _voiceNameController.text = bestMatch!['name']!;
      _voiceLocaleController.text = bestMatch['locale']!;
      _selectedVoiceKey = _voiceKey(bestMatch['name']!, bestMatch['locale']!);
      if (_languageController.text.trim().isEmpty) {
        _languageController.text = bestMatch['locale']!;
      }
    });
  }
}