// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;
import 'storage.dart';

import 'utils.dart' show snackBarAlert, Config, DecimalTextInputFormatter;

class ConfigPage extends StatefulWidget {
  final Function(Config) updateFunc;
  final Config currentConfig;
  const ConfigPage({super.key, required this.updateFunc, required this.currentConfig});

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

  @override
  void initState() {
    super.initState();
    getApiConfigs().then((List<Config> value) {
      debugPrint("Loaded API configs: $value");
      if(value.isEmpty){
        value.add(Config(name: "deepseek", baseUrl: "https://api.deepseek.com/v1", apiKey: "", model: "deepseek-chat", temperature: "1", frequencyPenalty: "", presencePenalty: "", maxTokens: "8192"));
        value.add(Config(name: "openai", baseUrl: "https://api.openai.com/v1", apiKey: "", model: "gpt-5", temperature: "1", frequencyPenalty: "", presencePenalty: "", maxTokens: "8192"));
        value.add(Config(name: "gemini", baseUrl: "https://generativelanguage.googleapis.com/v1beta", apiKey: "", model: "gemini-2.5-flash", temperature: "1", frequencyPenalty: "", presencePenalty: "", maxTokens: "8192"));
        value.add(Config(name: "grok", baseUrl: "https://api.grok.ai/v1", apiKey: "", model: "grok-4", temperature: "1", frequencyPenalty: "", presencePenalty: "", maxTokens: "8192"));
        value.add(Config(name: "openrouter", baseUrl: "https://openrouter.ai/api/v1", apiKey: "", model: "google/gemini-2.5-flash", temperature: "1", frequencyPenalty: "", presencePenalty: "", maxTokens: "8192"));
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
        frequencyPenaltyController.text = widget.currentConfig.frequencyPenalty ?? "";
        presencePenaltyController.text = widget.currentConfig.presencePenalty ?? "";
        maxTokensController.text = widget.currentConfig.maxTokens ?? "";
      });
    });
  }

  Future<void> deleteConfirm(BuildContext context, String config) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('确认删除'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('您确定要删除 "$config" 吗？'),
                const Text('此操作无法撤销。'),
              ],
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
              child: const Text('删除'),
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

  void saveConfig() {
    if (apiConfigs.isNotEmpty) {
      for (Config c in apiConfigs) {
        if (c.name == nameController.text) {
          // 删除旧配置
          deleteApiConfig(nameController.text);
          apiConfigs.remove(c);
        }
      }
    }
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
      maxTokens: maxTokensController.text.isEmpty
          ? null
          : maxTokensController.text,
    );
    setApiConfig(newConfig);
    setCurrentApiConfig(nameController.text);
    setState(() {
      apiConfigs.add(newConfig);
      selectedConfig = nameController.text;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('模型配置'),
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
              });
            },
          ),
          // 保存
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: () {
              saveConfig();
              widget.updateFunc(Config(
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
                maxTokens: maxTokensController.text.isEmpty
                    ? null
                    : maxTokensController.text,
              ));
              Navigator.pop(context);
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: 
        SingleChildScrollView(child: Column(
          children: [
            const ListTile(
              title: Text('预设管理', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey)),
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: '名称'),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  child: const Text('保存预设'),
                  onPressed: () {
                    if (nameController.text.isEmpty ||
                        urlController.text.isEmpty ||
                        keyController.text.isEmpty ||
                        modelController.text.isEmpty) {
                      snackBarAlert(context, "请填写所有字段");
                    } else {
                      saveConfig();
                      snackBarAlert(context, "保存成功");
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),
            DropdownButton<String>(
              value: selectedConfig,
              hint: const Text('选择预设'),
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
                      temperatureController.text = c.temperature ?? "";
                      frequencyPenaltyController.text = c.frequencyPenalty ?? "";
                      presencePenaltyController.text = c.presencePenalty ?? "";
                      maxTokensController.text = c.maxTokens ?? "";
                      widget.updateFunc(c);
                      break;
                    }
                  }
                });
                setCurrentApiConfig(selectedConfig!);
              },
            ),
            const Divider(),
            const SizedBox(height: 20),
            const ListTile(
              title: Text('配置参数', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey)),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: urlController,
              decoration: const InputDecoration(labelText: 'API地址'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: keyController,
              decoration: const InputDecoration(labelText: 'API密钥'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: modelController,
              decoration: const InputDecoration(labelText: '模型'),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: temperatureController,
                    decoration: const InputDecoration(labelText: '温度'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [DecimalTextInputFormatter()],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: frequencyPenaltyController,
                    decoration: const InputDecoration(labelText: '频率惩罚（可选）'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
                    decoration: const InputDecoration(labelText: '存在惩罚（可选）'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [DecimalTextInputFormatter()],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: maxTokensController,
                    decoration: const InputDecoration(labelText: '最大输出长度'),
                    keyboardType: const TextInputType.numberWithOptions(),
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                ),
              ],
            ),
          ],
        ),
        )
      ),
    );
  }
}
