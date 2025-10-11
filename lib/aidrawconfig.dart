import 'package:flutter/material.dart';
import 'package:momotalk/storage.dart';
import 'utils.dart';

class SdConfigPage extends StatelessWidget {
  final SdConfig sdConfig;
  
  const SdConfigPage({super.key, required this.sdConfig});

  @override
  Widget build(BuildContext context) {
    TextEditingController apiController = TextEditingController();
    TextEditingController sdPrompt = TextEditingController(text: sdConfig.prompt);
    TextEditingController sdNegative = TextEditingController(text: sdConfig.negativePrompt);
    TextEditingController sdModel = TextEditingController(text: sdConfig.model);
    TextEditingController sdSampler = TextEditingController(text: sdConfig.sampler);
    TextEditingController sdWidth = TextEditingController(text: sdConfig.width.toString());
    TextEditingController sdHeight = TextEditingController(text: sdConfig.height.toString());
    TextEditingController sdStep = TextEditingController(text: sdConfig.steps.toString());
    TextEditingController sdCFG = TextEditingController(text: sdConfig.cfg.toString());
    getDrawUrl().then((value) {
      apiController.text = value?? '';
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('绘图配置'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: () {
              if (int.parse(sdWidth.text) % 8 != 0) {
                sdWidth.text = (int.parse(sdWidth.text) ~/ 8 * 8).toString();
              }
              if (int.parse(sdHeight.text) % 8 != 0) {
                sdHeight.text = (int.parse(sdHeight.text) ~/ 8 * 8).toString();
              }
              SdConfig updatedConfig = SdConfig(
                prompt: sdPrompt.text,
                negativePrompt: sdNegative.text,
                model: sdModel.text,
                sampler: sdSampler.text,
                width: int.parse(sdWidth.text),
                height: int.parse(sdHeight.text),
                steps: int.parse(sdStep.text),
                cfg: int.parse(sdCFG.text),
              );
              setSdConfig(updatedConfig);
              setDrawUrl(apiController.text);
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
              decoration: const InputDecoration(labelText: "绘画API地址"),
            ),
            TextField(
              controller: sdPrompt,
              decoration: const InputDecoration(labelText: "正向提示词(输入 VERB 作为占位符)"),
            ),
            TextField(
              controller: sdNegative,
              decoration: const InputDecoration(labelText: "负向提示词"),
            ),
            TextField(
              controller: sdModel,
              decoration: const InputDecoration(labelText: "模型"),
            ),
            TextField(
              controller: sdSampler,
              decoration: const InputDecoration(labelText: "采样器"),
            ),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: sdWidth,
                  inputFormatters: [DecimalTextInputFormatter()],
                  decoration: const InputDecoration(labelText: "宽度"),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: sdHeight,
                  inputFormatters: [DecimalTextInputFormatter()],
                  decoration: const InputDecoration(labelText: "高度"),
                ),
              ),
            ]),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: sdStep,
                  inputFormatters: [DecimalTextInputFormatter()],
                  decoration: const InputDecoration(labelText: "步数"),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: sdCFG,
                  decoration: const InputDecoration(labelText: "CFG"),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}