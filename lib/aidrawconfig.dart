import 'package:flutter/material.dart';
import 'storage.dart';
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
            const ListTile(
              title: Text("基础配置",
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child:  Column(
                children: [
                  TextField(
                    controller: apiController,
                    decoration: const InputDecoration(labelText: "API地址"),
                  ),
                  TextField(
                    controller: sdModel,
                    decoration: const InputDecoration(labelText: "模型"),
                  ),
                ]
              )
            ),
            const ListTile(
              title: Text("采样配置",
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child:  Column(
                children: [
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
                ]
              )
            ),
            const ListTile(
              title: Text("提示词配置",
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child:  Column(
                children: [
                  TextField(
                    controller: sdPrompt,
                    decoration: const InputDecoration(labelText: "正向提示词(输入 VERB 作为占位符)"),
                    minLines: 2,
                    maxLines: 4,
                  ),
                  TextField(
                    controller: sdNegative,
                    decoration: const InputDecoration(labelText: "负向提示词"),
                    minLines: 2,
                    maxLines: 4,
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