import 'package:flutter/material.dart';
import 'storage.dart';
import 'utils.dart';
import 'i18n.dart';

class SdConfigPage extends StatefulWidget {
  final SdConfig sdConfig;

  const SdConfigPage({super.key, required this.sdConfig});

  @override
  State<SdConfigPage> createState() => _SdConfigPageState();
}

class _SdConfigPageState extends State<SdConfigPage> {
  // SD controllers
  final TextEditingController civitaiApiTokenController = TextEditingController();
  late final TextEditingController sdPrompt;
  late final TextEditingController sdNegative;
  late final TextEditingController sdModel;
  late final TextEditingController sdSampler;
  late final TextEditingController sdWidth;
  late final TextEditingController sdHeight;
  late final TextEditingController sdStep;
  late final TextEditingController sdCFG;
  late final TextEditingController sdSeed;
  late final TextEditingController sdClipSkip;
  late final TextEditingController gradioUrlController;

  // Aidraw LLM selection
  List<Config> apiConfigs = [];
  String? aidrawSelectedConfig;
  BackendType selectedBackend = BackendType.civitai;

  @override
  void initState() {
    super.initState();
    final s = widget.sdConfig;
    sdPrompt = TextEditingController(text: s.prompt);
    sdNegative = TextEditingController(text: s.negativePrompt);
    sdModel = TextEditingController(text: s.model);
    sdSampler = TextEditingController(text: s.sampler);
    sdWidth = TextEditingController(text: s.width.toString());
    sdHeight = TextEditingController(text: s.height.toString());
    sdStep = TextEditingController(text: s.steps.toString());
    sdCFG = TextEditingController(text: s.cfg.toString());
    sdSeed = TextEditingController(text: s.seed?.toString() ?? '');
    sdClipSkip = TextEditingController(text: s.clipSkip?.toString() ?? '');
    civitaiApiTokenController.text = s.civitaiApiToken ?? '';
    gradioUrlController = TextEditingController(text: s.gradioUrl ?? '');
    selectedBackend = s.backendType;

    getApiConfigs().then((cfgs) async {
      final name = await getAidrawApiName();
      if (!mounted) return;
      setState(() {
        apiConfigs = cfgs;
        aidrawSelectedConfig = name ?? (apiConfigs.isNotEmpty ? apiConfigs.first.name : null);
      });
    });
  }

  @override
  void dispose() {
    civitaiApiTokenController.dispose();
    sdPrompt.dispose();
    sdNegative.dispose();
    sdModel.dispose();
    sdSampler.dispose();
    sdWidth.dispose();
    sdHeight.dispose();
    sdStep.dispose();
    sdCFG.dispose();
    sdSeed.dispose();
    sdClipSkip.dispose();
    gradioUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                civitaiApiToken: civitaiApiTokenController.text.isNotEmpty ? civitaiApiTokenController.text : null,
                seed: int.tryParse(sdSeed.text),
                clipSkip: int.tryParse(sdClipSkip.text),
                backendType: selectedBackend,
                gradioUrl: gradioUrlController.text.isNotEmpty ? gradioUrlController.text : null,
              );
              setSdConfig(updatedConfig);
              Navigator.of(context).pop();
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
                title: Text(I18n.t('aidraw_prompt_llm'),
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(children: [
                  Expanded(
                    child: DropdownButton<String>(
                      value: aidrawSelectedConfig,
                      isExpanded: true,
                      items: apiConfigs
                          .map((c) => DropdownMenuItem<String>(
                                value: c.name,
                                child: Text(c.name),
                              ))
                          .toList(),
                      onChanged: (String? newValue) async {
                        setState(() {
                          aidrawSelectedConfig = newValue;
                        });
                        if (newValue != null) await setAidrawApiConfig(newValue);
                      },
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 20),
              ListTile(
                title: Text(I18n.t('backend_type'),
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: SegmentedButton<BackendType>(
                        segments: const [
                          ButtonSegment(
                            value: BackendType.civitai,
                            label: Text('Civitai'),
                          ),
                          ButtonSegment(
                            value: BackendType.gradio,
                            label: Text('Gradio'),
                          ),
                        ],
                        selected: {selectedBackend},
                        onSelectionChanged: (Set<BackendType> newSelection) {
                          setState(() {
                            selectedBackend = newSelection.first;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                title: Text(I18n.t('base_config'),
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(children: [
                  if (selectedBackend == BackendType.civitai)
                    TextField(
                      controller: civitaiApiTokenController,
                      decoration: const InputDecoration(
                        labelText: 'Civitai API Token',
                        helperText: 'Get your token from civitai.com',
                      ),
                      obscureText: true,
                    )
                  else
                    TextField(
                      controller: gradioUrlController,
                      decoration: const InputDecoration(
                        labelText: 'Gradio URL',
                        helperText: 'e.g., http://localhost:7860',
                      ),
                    ),
                  TextField(
                    controller: sdModel,
                    decoration: InputDecoration(
                      labelText: selectedBackend == BackendType.civitai ? 'Model URN' : 'Model Name',
                      helperText: selectedBackend == BackendType.civitai
                          ? 'e.g., urn:air:sdxl:checkpoint:civitai:101055@128078'
                          : 'e.g., sd_xl_base_1.0.safetensors',
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 20),
              ListTile(
                title: Text(I18n.t('sampler_config'),
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(children: [
                  TextField(
                    controller: sdSampler,
                    decoration: const InputDecoration(
                      labelText: 'Sampler/Scheduler',
                      helperText: 'e.g., EulerA, DPM++ 2M Karras, Euler',
                    ),
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
                  Row(children: [
                    Expanded(
                      child: TextField(
                        controller: sdSeed,
                        inputFormatters: [DecimalTextInputFormatter()],
                        decoration: const InputDecoration(
                          labelText: 'Seed',
                          helperText: 'Optional: -1 for random',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: sdClipSkip,
                        inputFormatters: [DecimalTextInputFormatter()],
                        decoration: const InputDecoration(
                          labelText: 'Clip Skip',
                          helperText: 'Optional: 1-2',
                        ),
                      ),
                    ),
                  ]),
                ]),
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
                child: Column(children: [
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
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}