import 'package:flutter/material.dart';
import 'package:momotalk/storage.dart';
import 'utils.dart';

class VitsConfigPage extends StatelessWidget {
  final VitsConfig vitsConfig;
  
  const VitsConfigPage({super.key, required this.vitsConfig});

  @override
  Widget build(BuildContext context) {
    TextEditingController apiController = TextEditingController();
    TextEditingController vitsModel = TextEditingController(text: vitsConfig.model);
    TextEditingController vitsLanguage = TextEditingController(text: vitsConfig.language);
    TextEditingController vitsNoiseScale = TextEditingController(text: vitsConfig.noiseScale.toString());
    TextEditingController vitsNoiseScaleW = TextEditingController(text: vitsConfig.noiseScaleW.toString());
    TextEditingController vitsLengthScale = TextEditingController(text: vitsConfig.lengthScale.toString());
    getVitsUrl().then((value) {
      apiController.text = value?? '';
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('语音配置'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: () {
              VitsConfig updatedConfig = VitsConfig(
                model: vitsModel.text,
                language: vitsLanguage.text,
                noiseScale: double.tryParse(vitsNoiseScale.text) ?? 0.6,
                noiseScaleW: double.tryParse(vitsNoiseScaleW.text) ?? 0.7,
                lengthScale: double.tryParse(vitsLengthScale.text) ?? 1.2,
              );
              setVitsConfig(updatedConfig);
              setVitsUrl(apiController.text);
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: apiController,
              decoration: const InputDecoration(labelText: "语音API地址"),
            ),
            TextField(
              controller: vitsModel,
              decoration: const InputDecoration(labelText: "模型名称"),
            ),
            TextField(
              controller: vitsLanguage,
              decoration: const InputDecoration(labelText: "语言"),
            ),
            TextField(
              controller: vitsNoiseScale,
              decoration: const InputDecoration(labelText: "噪声缩放"),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: vitsNoiseScaleW,
              decoration: const InputDecoration(labelText: "噪声缩放宽度"),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: vitsLengthScale,
              decoration: const InputDecoration(labelText: "长度缩放"),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
      ),
    );
  }
}