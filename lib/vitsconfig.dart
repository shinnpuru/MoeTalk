import 'package:flutter/material.dart';
import 'storage.dart';
import 'utils.dart';

class VitsConfigPage extends StatelessWidget {
  final VitsConfig vitsConfig;
  
  const VitsConfigPage({super.key, required this.vitsConfig});

  @override
  Widget build(BuildContext context) {
    TextEditingController apiController = TextEditingController();
    TextEditingController vitsPrompt = TextEditingController(text: vitsConfig.prompt);
    TextEditingController vitsHappy = TextEditingController(text: vitsConfig.happy?.toString() ?? '0.0');
    TextEditingController vitsSad = TextEditingController(text: vitsConfig.sad?.toString() ?? '0.0');
    TextEditingController vitsAngry = TextEditingController(text: vitsConfig.angry?.toString() ?? '0.0');
    TextEditingController vitsAfraid = TextEditingController(text: vitsConfig.angry?.toString() ?? '0.0');
    TextEditingController vitsDisgusted = TextEditingController(text: vitsConfig.happy?.toString() ?? '0.0');
    TextEditingController vitsMelancholic = TextEditingController(text: vitsConfig.sad?.toString() ?? '0.0');
    TextEditingController vitsSurprised = TextEditingController(text: vitsConfig.angry?.toString() ?? '0.0');
    TextEditingController vitsCalm = TextEditingController(text: vitsConfig.angry?.toString() ?? '0.0');
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
                prompt: vitsPrompt.text,
                happy: double.tryParse(vitsHappy.text) ?? 0.0,
                sad: double.tryParse(vitsSad.text) ?? 0.0,
                angry: double.tryParse(vitsAngry.text) ?? 0.0,
                afraid: double.tryParse(vitsAfraid.text) ?? 0.0,
                disgusted: double.tryParse(vitsDisgusted.text) ?? 0.0,
                melancholic: double.tryParse(vitsMelancholic.text) ?? 0.0,
                surprised: double.tryParse(vitsSurprised.text) ?? 0.0,
                calm: double.tryParse(vitsCalm.text) ?? 0.0,
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
              controller: vitsPrompt,
              decoration: const InputDecoration(labelText: "语音参考地址"),
            ),
            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      TextField(
                        controller: vitsHappy,
                        decoration: const InputDecoration(labelText: "快乐"),
                      ),
                      TextField(
                        controller: vitsSad,
                        decoration: const InputDecoration(labelText: "悲伤"),
                      ),
                      TextField(
                        controller: vitsAngry,
                        decoration: const InputDecoration(labelText: "愤怒"),
                      ),
                      TextField(
                        controller: vitsAfraid,
                        decoration: const InputDecoration(labelText: "恐惧"),
                      ),
                    ],
                  ),
                ),
                const Padding(padding: EdgeInsets.symmetric(horizontal: 8.0)),
                Expanded(
                  child: Column(
                    children: [
                      TextField(
                        controller: vitsDisgusted,
                        decoration: const InputDecoration(labelText: "厌恶"),
                      ),
                      TextField(
                        controller: vitsMelancholic,
                        decoration: const InputDecoration(labelText: "忧郁"),
                      ),
                      TextField(
                        controller: vitsSurprised,
                        decoration: const InputDecoration(labelText: "惊讶"),
                      ),
                      TextField(
                        controller: vitsCalm,
                        decoration: const InputDecoration(labelText: "平静"),
                      ),
                    ],
                  ),
                )
              ],
            )
          ],
        ),
      ),
    );
  }
}