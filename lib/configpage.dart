// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;
import 'storage.dart';
import 'i18n.dart';
import 'openai.dart' show testModelConnection;

import 'utils.dart'
    show
        snackBarAlert,
        Config,
        DecimalTextInputFormatter,
        ThinkingMode,
        ThinkingApi;

class ConfigPage extends StatefulWidget {
  final Function(Config) updateFunc;
  final Config currentConfig;
  const ConfigPage(
      {super.key, required this.updateFunc, required this.currentConfig});

  @override
  ConfigPageState createState() => ConfigPageState();
}

class ConfigPageState extends State<ConfigPage> {
  String? selectedConfig;
  List<Config> apiConfigs = [];
  TextEditingController nameController = TextEditingController();
  TextEditingController urlController = TextEditingController();
  TextEditingController keyController = TextEditingController();
  TextEditingController modelController = TextEditingController();
  TextEditingController temperatureController = TextEditingController();
  TextEditingController frequencyPenaltyController = TextEditingController();
  TextEditingController presencePenaltyController = TextEditingController();
  TextEditingController maxTokensController = TextEditingController();
  ThinkingMode _thinkingMode = ThinkingMode.automatic;
  String? _thinkingEffort;
  ThinkingApi _thinkingApi = ThinkingApi.automatic;
  bool _testingConnection = false;
  bool _connectionSuccessful = false;
  String? _connectionResult;
  int _configRevision = 0;

  List<TextEditingController> get _controllers => [
        nameController,
        urlController,
        keyController,
        modelController,
        temperatureController,
        frequencyPenaltyController,
        presencePenaltyController,
        maxTokensController,
      ];

  void _onConfigEdited() {
    _configRevision++;
    if (_connectionResult != null) {
      setState(() => _connectionResult = null);
    }
  }

  Future<void> _testConnection() async {
    if (_testingConnection) return;
    final url = Uri.tryParse(urlController.text.trim());
    if (url == null ||
        !url.hasAuthority ||
        url.host.isEmpty ||
        (url.scheme != 'http' && url.scheme != 'https') ||
        modelController.text.trim().isEmpty) {
      snackBarAlert(context, I18n.t('llm_connection_fields_required'));
      return;
    }
    final config = Config(
      name: nameController.text,
      baseUrl: urlController.text.trim(),
      apiKey: keyController.text.trim(),
      model: modelController.text.trim(),
      temperature: temperatureController.text,
      frequencyPenalty: frequencyPenaltyController.text,
      presencePenalty: presencePenaltyController.text,
      maxTokens: maxTokensController.text,
      thinkingMode: _thinkingMode,
      thinkingEffort: _thinkingEffort,
      thinkingApi: _thinkingApi,
    );
    final revision = _configRevision;
    setState(() {
      _testingConnection = true;
      _connectionResult = null;
    });
    try {
      await testModelConnection(config);
      if (!mounted || revision != _configRevision) return;
      setState(() {
        _connectionSuccessful = true;
        _connectionResult = I18n.t('connection_success');
      });
    } catch (error) {
      if (!mounted || revision != _configRevision) return;
      setState(() {
        _connectionSuccessful = false;
        _connectionResult = '${I18n.t('connection_failed')}: $error';
      });
    } finally {
      if (mounted) setState(() => _testingConnection = false);
    }
  }

  @override
  void initState() {
    super.initState();
    for (final controller in _controllers) {
      controller.addListener(_onConfigEdited);
    }
    getApiConfigs().then((List<Config> value) {
      if (!mounted) return;
      debugPrint("Loaded API configs: $value");
      if (value.isEmpty) {
        value.add(Config(
            name: "deepseek",
            baseUrl: "https://api.deepseek.com/v1",
            apiKey: "",
            model: "deepseek-chat",
            temperature: "1",
            frequencyPenalty: "",
            presencePenalty: "",
            maxTokens: "8192"));
        value.add(Config(
            name: "openai",
            baseUrl: "https://api.openai.com/v1",
            apiKey: "",
            model: "gpt-5",
            temperature: "1",
            frequencyPenalty: "",
            presencePenalty: "",
            maxTokens: "8192"));
        value.add(Config(
            name: "gemini",
            baseUrl: "https://generativelanguage.googleapis.com/v1beta/openai",
            apiKey: "",
            model: "gemini-2.5-flash",
            temperature: "1",
            frequencyPenalty: "",
            presencePenalty: "",
            maxTokens: "8192"));
        value.add(Config(
            name: "grok",
            baseUrl: "https://api.grok.ai/v1",
            apiKey: "",
            model: "grok-4",
            temperature: "1",
            frequencyPenalty: "",
            presencePenalty: "",
            maxTokens: "8192"));
        value.add(Config(
            name: "openrouter",
            baseUrl: "https://openrouter.ai/api/v1",
            apiKey: "",
            model: "google/gemini-2.5-flash",
            temperature: "1",
            frequencyPenalty: "",
            presencePenalty: "",
            maxTokens: "8192"));
      }

      setState(() {
        apiConfigs = value;
        for (Config c in apiConfigs) {
          if (c.name == widget.currentConfig.name) {
            selectedConfig = c.name;
            break;
          }
        }
        nameController.text = widget.currentConfig.name;
        urlController.text = widget.currentConfig.baseUrl;
        keyController.text = widget.currentConfig.apiKey;
        modelController.text = widget.currentConfig.model;
        temperatureController.text = widget.currentConfig.temperature ?? "";
        frequencyPenaltyController.text =
            widget.currentConfig.frequencyPenalty ?? "";
        presencePenaltyController.text =
            widget.currentConfig.presencePenalty ?? "";
        maxTokensController.text = widget.currentConfig.maxTokens ?? "";
        _thinkingMode = widget.currentConfig.thinkingMode;
        _thinkingEffort = widget.currentConfig.thinkingEffort;
        _thinkingApi = widget.currentConfig.thinkingApi;
      });
    });
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.removeListener(_onConfigEdited);
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> deleteConfirm(BuildContext context, String config) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(I18n.t('confirm_delete')),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text(I18n.t('delete_confirm_msg').replaceFirst('?', config)),
                Text(I18n.t('cannot_undo')),
              ],
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
              child: Text(I18n.t('delete')),
              onPressed: () {
                setState(() {
                  for (Config c in apiConfigs) {
                    if (c.name == config) {
                      deleteApiConfig(config);
                      apiConfigs.remove(c);
                      if (selectedConfig == config) {
                        if (apiConfigs.isNotEmpty) {
                          selectedConfig = apiConfigs[0].name;
                        }
                      }
                      break;
                    }
                  }
                });
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<Config> saveConfig() async {
    Config newConfig = Config(
      name: nameController.text,
      baseUrl: urlController.text,
      apiKey: keyController.text,
      model: modelController.text,
      temperature: temperatureController.text.isEmpty
          ? null
          : temperatureController.text,
      frequencyPenalty: frequencyPenaltyController.text.isEmpty
          ? null
          : frequencyPenaltyController.text,
      presencePenalty: presencePenaltyController.text.isEmpty
          ? null
          : presencePenaltyController.text,
      maxTokens:
          maxTokensController.text.isEmpty ? null : maxTokensController.text,
      thinkingMode: _thinkingMode,
      thinkingEffort: _thinkingEffort,
      thinkingApi: _thinkingApi,
    );
    await setApiConfig(newConfig);
    await setCurrentApiConfig(newConfig.name);
    if (!mounted) return newConfig;
    setState(() {
      apiConfigs.removeWhere((config) => config.name == newConfig.name);
      apiConfigs.add(newConfig);
      selectedConfig = newConfig.name;
    });
    return newConfig;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(I18n.t('model_config')),
        actions: [
          // 初始化
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                nameController.clear();
                urlController.clear();
                keyController.clear();
                modelController.clear();
                temperatureController.clear();
                frequencyPenaltyController.clear();
                presencePenaltyController.clear();
                maxTokensController.clear();
                _thinkingMode = ThinkingMode.automatic;
                _thinkingEffort = null;
                _thinkingApi = ThinkingApi.automatic;
                _onConfigEdited();
              });
            },
          ),
          // 保存
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: () async {
              final savedConfig = await saveConfig();
              if (!mounted) return;
              widget.updateFunc(savedConfig);
              Navigator.pop(context);
            },
          ),
        ],
      ),
      body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: Column(
              children: [
                ListTile(
                  title: Text(I18n.t('preset_manage'),
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey)),
                ),
                Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Column(children: [
                      DropdownButton<String>(
                        value: selectedConfig,
                        hint: Text(I18n.t('select_preset')),
                        isExpanded: true,
                        items: apiConfigs.map((Config config) {
                          return DropdownMenuItem<String>(
                            value: config.name,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(config.name),
                                IconButton(
                                  icon: const Icon(Icons.delete),
                                  onPressed: () {
                                    deleteConfirm(context, config.name);
                                  },
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          setState(() {
                            selectedConfig = newValue;
                            for (Config c in apiConfigs) {
                              if (c.name == newValue) {
                                nameController.text = c.name;
                                urlController.text = c.baseUrl;
                                keyController.text = c.apiKey;
                                modelController.text = c.model;
                                temperatureController.text =
                                    c.temperature ?? "";
                                frequencyPenaltyController.text =
                                    c.frequencyPenalty ?? "";
                                presencePenaltyController.text =
                                    c.presencePenalty ?? "";
                                maxTokensController.text = c.maxTokens ?? "";
                                _thinkingMode = c.thinkingMode;
                                _thinkingEffort = c.thinkingEffort;
                                _thinkingApi = c.thinkingApi;
                                _onConfigEdited();
                                widget.updateFunc(c);
                                break;
                              }
                            }
                          });
                          setCurrentApiConfig(selectedConfig!);
                        },
                      ),
                    ])),
                const SizedBox(height: 20),
                ListTile(
                  title: Text(I18n.t('config_params'),
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey)),
                ),
                Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Column(children: [
                      TextField(
                        controller: nameController,
                        decoration: InputDecoration(labelText: I18n.t('name')),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: urlController,
                        decoration:
                            InputDecoration(labelText: I18n.t('api_url')),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: keyController,
                        decoration:
                            InputDecoration(labelText: I18n.t('api_key')),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: modelController,
                        decoration: InputDecoration(labelText: I18n.t('model')),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<ThinkingMode>(
                        key: ValueKey('thinking-mode-${_thinkingMode.name}'),
                        // Flutter 3.29 does not have initialValue yet.
                        // ignore: deprecated_member_use
                        value: _thinkingMode,
                        isExpanded: true,
                        decoration:
                            InputDecoration(labelText: I18n.t('thinking_mode')),
                        items: ThinkingMode.values.map((mode) {
                          return DropdownMenuItem(
                            value: mode,
                            child: Text(I18n.t('thinking_${mode.name}')),
                          );
                        }).toList(),
                        onChanged: (mode) {
                          if (mode == null) return;
                          setState(() {
                            _thinkingMode = mode;
                            _onConfigEdited();
                          });
                        },
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        key: ValueKey('thinking-effort-$_thinkingEffort'),
                        // Flutter 3.29 does not have initialValue yet.
                        // ignore: deprecated_member_use
                        value: _thinkingEffort ?? 'default',
                        isExpanded: true,
                        decoration: InputDecoration(
                            labelText: I18n.t('thinking_effort')),
                        items:
                            ['default', 'low', 'medium', 'high'].map((effort) {
                          return DropdownMenuItem(
                            value: effort,
                            child: Text(I18n.t('thinking_$effort')),
                          );
                        }).toList(),
                        onChanged: _thinkingMode == ThinkingMode.disabled
                            ? null
                            : (effort) {
                                setState(() {
                                  _thinkingEffort =
                                      effort == 'default' ? null : effort;
                                  _onConfigEdited();
                                });
                              },
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<ThinkingApi>(
                        key: ValueKey('thinking-api-${_thinkingApi.name}'),
                        // Flutter 3.29 does not have initialValue yet.
                        // ignore: deprecated_member_use
                        value: _thinkingApi,
                        isExpanded: true,
                        decoration:
                            InputDecoration(labelText: I18n.t('thinking_api')),
                        items: ThinkingApi.values.map((api) {
                          return DropdownMenuItem(
                            value: api,
                            child: Text(api == ThinkingApi.automatic
                                ? I18n.t('auto')
                                : {
                                    ThinkingApi.openai: 'OpenAI / Gemini',
                                    ThinkingApi.deepseek: 'DeepSeek',
                                    ThinkingApi.openrouter: 'OpenRouter',
                                    ThinkingApi.llamaCpp: 'llama.cpp',
                                  }[api]!),
                          );
                        }).toList(),
                        onChanged: (api) {
                          if (api == null) return;
                          setState(() {
                            _thinkingApi = api;
                            _onConfigEdited();
                          });
                        },
                      ),
                      const SizedBox(height: 8),
                      Text(I18n.t('thinking_hint'),
                          style: Theme.of(context).textTheme.bodySmall),
                      const SizedBox(height: 10),
                      ElevatedButton.icon(
                        onPressed: _testingConnection ? null : _testConnection,
                        icon: _testingConnection
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.network_check),
                        label: Text(I18n.t(_testingConnection
                            ? 'llm_connection_testing'
                            : 'llm_test_connection')),
                      ),
                      if (_connectionResult != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: SelectableText(
                            _connectionResult!,
                            style: TextStyle(
                              color: _connectionSuccessful
                                  ? Colors.green
                                  : Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: temperatureController,
                              decoration: InputDecoration(
                                  labelText: I18n.t('temperature')),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              inputFormatters: [DecimalTextInputFormatter()],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: frequencyPenaltyController,
                              decoration: InputDecoration(
                                  labelText: I18n.t('frequency_penalty')),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              inputFormatters: [DecimalTextInputFormatter()],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: presencePenaltyController,
                              decoration: InputDecoration(
                                  labelText: I18n.t('presence_penalty')),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              inputFormatters: [DecimalTextInputFormatter()],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: maxTokensController,
                              decoration: InputDecoration(
                                  labelText: I18n.t('max_output_length')),
                              keyboardType:
                                  const TextInputType.numberWithOptions(),
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton(
                        child: Text(I18n.t('save_preset')),
                        onPressed: () async {
                          if (nameController.text.isEmpty ||
                              urlController.text.isEmpty ||
                              modelController.text.isEmpty) {
                            snackBarAlert(context, I18n.t('please_fill_all'));
                          } else {
                            await saveConfig();
                            if (!mounted) return;
                            snackBarAlert(context, I18n.t('save_success'));
                          }
                        },
                      ),
                    ]))
              ],
            ),
          )),
    );
  }
}
