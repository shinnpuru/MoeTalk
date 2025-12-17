import 'package:flutter/material.dart';
import 'storage.dart';
import 'utils.dart';
import 'i18n.dart';

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
        title: Text(I18n.t('drawing_config')),
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
                    controller: apiController,
                    decoration: InputDecoration(labelText: I18n.t('api_url')),
                  ),
                  TextField(
                    controller: sdModel,
                    decoration: InputDecoration(labelText: I18n.t('model')),
                  ),
                ]
              )
            ),
            ListTile(
              title: Text(I18n.t('sampler_config'),
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
                    controller: sdSampler,
                    decoration: InputDecoration(labelText: I18n.t('sampler')),
                  ),
                  Row(children: [
                    Expanded(
                      child: TextField(
                        controller: sdWidth,
                        inputFormatters: [DecimalTextInputFormatter()],
                        decoration: InputDecoration(labelText: I18n.t('width')),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: sdHeight,
                        inputFormatters: [DecimalTextInputFormatter()],
                        decoration: InputDecoration(labelText: I18n.t('height')),
                      ),
                    ),
                  ]),
                  Row(children: [
                    Expanded(
                      child: TextField(
                        controller: sdStep,
                        inputFormatters: [DecimalTextInputFormatter()],
                        decoration: InputDecoration(labelText: I18n.t('steps')),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: sdCFG,
                        decoration: InputDecoration(labelText: I18n.t('cfg')),
                      ),
                    ),
                  ]),
                ]
              )
            ),
            ListTile(
              title: Text(I18n.t('prompt_config'),
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
                    controller: sdPrompt,
                    decoration: InputDecoration(labelText: I18n.t('positive_prompt')),
                    minLines: 2,
                    maxLines: 4,
                  ),
                  TextField(
                    controller: sdNegative,
                    decoration: InputDecoration(labelText: I18n.t('negative_prompt')),
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