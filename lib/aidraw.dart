import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'dart:convert';
import 'utils.dart';
import 'openai.dart';
import 'notifications.dart';
import 'storage.dart';
import 'i18n.dart';
import 'civitai_client.dart';

Future<String?> generateImageTask({
  required String promptText,
  required SdConfig sdConfig,
}) async {
  if (sdConfig.backendType == BackendType.gradio) {
    return _generateImageWithGradio(promptText: promptText, sdConfig: sdConfig);
  } else {
    return _generateImageWithCivitai(promptText: promptText, sdConfig: sdConfig);
  }
}

Future<String?> _generateImageWithCivitai({
  required String promptText,
  required SdConfig sdConfig,
}) async {
  if (sdConfig.civitaiApiToken == null || sdConfig.civitaiApiToken!.isEmpty) {
    throw Exception('Civitai API token is not configured');
  }

  final civitaiClient = CivitaiClient(apiToken: sdConfig.civitaiApiToken!);

  String prompt = sdConfig.prompt;
  if(!prompt.contains("CHAR")){
    prompt += ", CHAR";
  }
  if(!prompt.contains("VERB")){
    prompt += ", VERB";
  }
  String? charPrompt = await getDrawCharPrompt();
  String finalPrompt = prompt
      .replaceAll("VERB", promptText)
      .replaceAll("CHAR", charPrompt);

  String? lora = await getDrawLora();
  Map<String, dynamic>? additionalNetworks;
  if (lora != null && lora.isNotEmpty) {
    final loraPattern = RegExp(r'<([^:]+):([0-9.]+)>');
    final matches = loraPattern.allMatches(lora);
    if (matches.isNotEmpty) {
      additionalNetworks = {};
      for (var match in matches) {
        String airUrn = match.group(1)!;
        double weight = double.tryParse(match.group(2)!) ?? 1.0;
        additionalNetworks[airUrn] = {'strength': weight};
      }
    } else {
      additionalNetworks = {
        lora: {'strength': 1.0},
      };
    }
  }

  final input = ImageInput(
    model: sdConfig.model,
    params: ImageParams(
      prompt: finalPrompt,
      negativePrompt: sdConfig.negativePrompt,
      width: sdConfig.width ?? 1024,
      height: sdConfig.height ?? 1600,
      steps: sdConfig.steps ?? 28,
      cfgScale: (sdConfig.cfg ?? 7).toDouble(),
      scheduler: sdConfig.sampler,
      seed: sdConfig.seed,
      clipSkip: sdConfig.clipSkip,
    ),
    additionalNetworks: additionalNetworks,
  );

  final response = await civitaiClient.image.create(
    input: input,
    wait: true,
    timeout: const Duration(minutes: 10),
    pollInterval: const Duration(seconds: 2),
  );

  if (response.jobs.isNotEmpty) {
    for (var job in response.jobs) {
      final url = job.imageUrl;
      if (url != null && url.isNotEmpty) {
        return url;
      }
    }
  }
  return null;
}

Future<String?> _generateImageWithGradio({
  required String promptText,
  required SdConfig sdConfig,
}) async {
  String url = sdConfig.gradioUrl ?? '';
  if (url.isEmpty) {
    throw Exception('Gradio URL is not configured');
  }

  if(!url.endsWith('/')) {
    url += '/';
  }

  String? sessionHash;
  String lastModel = "";
  final dio = Dio(BaseOptions(baseUrl: url));
  final cancelToken = CancelToken();

  try {
    // Load model if needed
    if(lastModel != sdConfig.model) {
      final Response response = await dio.post(
        "/gradio_api/call/load_new_model",
        data: {
          "data": [sdConfig.model, "None", "txt2img", "Automatic"],
        },
        cancelToken: cancelToken,
      );
      final data = response.data.toString();
      sessionHash = data.substring(11,data.length-1);

      final Response<ResponseBody> loadModelQueue = await dio.get<ResponseBody>(
        "/gradio_api/call/load_new_model/$sessionHash",
        options: Options(responseType: ResponseType.stream),
        cancelToken: cancelToken,
      );
      await for (var chunk in loadModelQueue.data!.stream) {
        // Model loading log
      }
    }

    // Prepare prompt
    String prompt = sdConfig.prompt;
    if(!prompt.contains("CHAR")){
      prompt += ", CHAR";
    }
    if(!prompt.contains("VERB")){
      prompt += ", VERB";
    }
    String? charPrompt = await getDrawCharPrompt();
    String finalPrompt = prompt.replaceAll("VERB", promptText).replaceAll("CHAR", charPrompt);

    // Get LoRA configuration
    String? lora = await getDrawLora();
    // Parse LoRA: format is "lora_name" or "<lora_name:weight>"
    // For Gradio backend, we place LoRA names in the null positions of the data array
    // First LoRA name at index 7 (first null), weight is 0.33 at index 8
    // Second LoRA name at index 9 (second null), weight is 0.33 at index 10, etc.
    List<String?> loraParams = List.filled(8, null); // 4 pairs of (name, weight)
    List<double> loraWeights = [0.33, 0.33, 0.33, 0.33]; // default weights

    if (lora != null && lora.isNotEmpty) {
      final loraPattern = RegExp(r'<([^:]+):([0-9.]+)>');
      final matches = loraPattern.allMatches(lora);
      if (matches.isNotEmpty) {
        int idx = 0;
        for (var match in matches) {
          if (idx >= 4) break; // Max 4 LoRAs
          String loraName = match.group(1)!;
          double weight = double.tryParse(match.group(2)!) ?? 0.33;
          loraParams[idx] = loraName;
          loraWeights[idx] = weight;
          idx++;
        }
      } else {
        // Simple LoRA name without weight
        loraParams[0] = lora;
      }
    }

    // Build data array with LoRAs in the correct positions
    // Positions: 7=null, 8=0.33, 9=null, 10=0.33, 11=null, 12=0.33, 13=null, 14=0.33
    final Response response = await dio.post(
      "/gradio_api/call/sd_gen_generate_pipeline",
      data: {
        "data": [
          finalPrompt,
          sdConfig.negativePrompt,
          1,
          sdConfig.steps ?? 28,
          sdConfig.cfg ?? 7,
          true,
          -1,
          loraParams[0], // First LoRA name (null if not set)
          loraWeights[0], // First LoRA weight
          loraParams[1], // Second LoRA name
          loraWeights[1], // Second LoRA weight
          loraParams[2], // Third LoRA name
          loraWeights[2], // Third LoRA weight
          loraParams[3], // Fourth LoRA name
          loraWeights[3], // Fourth LoRA weight
          sdConfig.sampler,
          "Automatic",
          "Automatic",
          sdConfig.height ?? 1600,
          sdConfig.width ?? 1024,
          sdConfig.model,
          null,
          "txt2img",
          null,
          null,
          512,
          1024,
          null,
          null,
          null,
          0.55,
          100,
          200,
          1,
          1,
          1,
          9,
          1,
          0,
          1,
          false,
          "Classic",
          null,
          1.2,
          0,
          8,
          30,
          0.55,
          "Use same sampler",
          "",
          "",
          false,
          true,
          "Use same schedule type",
          -1,
          "Automatic",
          1,
          true,
          false,
          true,
          true,
          true,
          "model,seed",
          "./images",
          false,
          false,
          false,
          true,
          1,
          0.55,
          false,
          false,
          false,
          true,
          false,
          "Use same sampler",
          false,
          "",
          "",
          0.35,
          true,
          false,
          false,
          4,
          4,
          32,
          false,
          "",
          "",
          0.35,
          false,
          true,
          false,
          4,
          4,
          32,
          false,
          0,
          null,
          null,
          "plus_face",
          "original",
          0.7,
          null,
          null,
          "base",
          "style",
          0.7,
          0,
          null,
          1,
          0.5,
          false,
          false,
          59
        ],
      },
      cancelToken: cancelToken,
    );

    final data = response.data.toString();
    sessionHash = data.substring(11,data.length-1);

    // Inference queue
    final Response<ResponseBody> inferQueue = await dio.get<ResponseBody>(
      "/gradio_api/call/sd_gen_generate_pipeline/$sessionHash",
      options: Options(responseType: ResponseType.stream),
      cancelToken: cancelToken,
    );

    String lastUrl = '';
    final regexWebp = RegExp(r'download=\\"(.+?)\\"');
    final regexPng = RegExp(r'href=\\"(.+?)\\"');

    await for (var chunk in inferQueue.data!.stream) {
      String data = utf8.decode(chunk);
      final match = regexWebp.allMatches(data);
      if (match.isNotEmpty) {
        lastUrl = match.last.group(1)!;
      }
      if (data.contains('COMPLETE')) {
        if(lastUrl.isNotEmpty) {
          return "${url}gradio_api/file=images/$lastUrl";
        }
      }
    }

    return null;
  } finally {
    cancelToken.cancel();
  }
}

class AiDraw extends StatefulWidget {
  final List<List<String>>? msg;
  final Config config;
  final String? initialImageUrl;
  final String? promptForRedraw;
  const AiDraw({super.key, required this.msg, required this.config, this.initialImageUrl, this.promptForRedraw});

  @override
  AiDrawState createState() => AiDrawState();
}

class AiDrawState extends State<AiDraw> with WidgetsBindingObserver{
  TextEditingController descriptionController = TextEditingController();
  TextEditingController logController = TextEditingController();
  TextEditingController promptController = TextEditingController();
  String lastModel = "";
  String url="";
  String? imageUrl;
  String? imageUrlRaw;
  String? jobToken;
  bool gptBusy = false, sdBusy = false, showLog = false;
  bool isForeground = true;
  final notification = NotificationHelper();
  CancelToken cancelToken = CancelToken();
  late SdConfig sdConfig;
  CivitaiClient? civitaiClient;

  Future<void> buildPrompt() async {
    setState(() {
      gptBusy = true;
    });
    List<List<String>> messages = widget.msg?? [];
    String result = '';
    final Config? aidrawCfg = await getAidrawApiConfig();
    final Config configToUse = aidrawCfg ?? widget.config;
    await completion(configToUse, messages,
      (String data) async{
        result += data.replaceAll("\n", " ");
        promptController.text = result.split('||').last.replaceAll(RegExp(await getResponseRegex()), '');
      },
      () {
        setState(() {
          gptBusy = false;
        });
      },
      (String error) {
        setState(() {
          gptBusy = false;
        });
        logController.text = '$error\n${logController.text}';
        snackBarAlert(context, "${I18n.t('error')} $error");
      });
  }

  Future<void> makeRequest() async {
    setState(() {
      sdBusy = true;
      showLog = true;
    });

    try {
      // Prepare prompt
      if(!sdConfig.prompt.contains("CHAR")){
        sdConfig.prompt += ", CHAR";
      }
      if(!sdConfig.prompt.contains("VERB")){
        sdConfig.prompt += ", VERB";
      }
      String? charPrompt = await getDrawCharPrompt();
      String finalPrompt = sdConfig.prompt
          .replaceAll("VERB", promptController.text)
          .replaceAll("CHAR", charPrompt);

      logController.text = 'Generating image with prompt:\n$finalPrompt\n${logController.text}';

      if (sdConfig.backendType == BackendType.gradio) {
        await _makeGradioRequest(finalPrompt);
      } else {
        await _makeCivitaiRequest(finalPrompt);
      }
    } catch (e) {
      debugPrint('Error during image generation: $e');
      logController.text = 'Error: $e\n${logController.text}';
      setState(() {
        sdBusy = false;
        showLog = true;
      });
      if (mounted) {
        snackBarAlert(context, "${I18n.t('error')} $e");
      }
    }
  }

  Future<void> _makeCivitaiRequest(String finalPrompt) async {
    // Initialize Civitai client if API token is available
    if (sdConfig.civitaiApiToken == null || sdConfig.civitaiApiToken!.isEmpty) {
      throw Exception('Civitai API token is not configured');
    }

    civitaiClient = CivitaiClient(apiToken: sdConfig.civitaiApiToken!);

    logController.text = 'Initializing Civitai API...\n${logController.text}';

    // Get LoRA configuration
    String? lora = await getDrawLora();
    Map<String, dynamic>? additionalNetworks;
    if (lora != null && lora.isNotEmpty) {
      final loraPattern = RegExp(r'<([^:]+):([0-9.]+)>');
      final matches = loraPattern.allMatches(lora);

      if (matches.isNotEmpty) {
        additionalNetworks = {};
        for (var match in matches) {
          String airUrn = match.group(1)!;
          double weight = double.tryParse(match.group(2)!) ?? 1.0;
          additionalNetworks[airUrn] = {'strength': weight};
          logController.text = 'Using LoRA: $airUrn (weight: $weight)\n${logController.text}';
        }
      } else {
        additionalNetworks = {
          lora: {'strength': 1.0},
        };
        logController.text = 'Using LoRA: $lora (weight: 1.0)\n${logController.text}';
      }
    }

    // Create image generation request
    final input = ImageInput(
      model: sdConfig.model,
      params: ImageParams(
        prompt: finalPrompt,
        negativePrompt: sdConfig.negativePrompt,
        width: sdConfig.width ?? 1024,
        height: sdConfig.height ?? 1600,
        steps: sdConfig.steps ?? 28,
        cfgScale: (sdConfig.cfg ?? 7).toDouble(),
        scheduler: sdConfig.sampler,
        seed: sdConfig.seed,
        clipSkip: sdConfig.clipSkip,
      ),
      additionalNetworks: additionalNetworks,
    );

    logController.text = 'Submitting job to Civitai...\n${logController.text}';

    // Submit the job and wait for completion
    final response = await civitaiClient!.image.create(
      input: input,
      wait: true,
      timeout: const Duration(minutes: 10),
      pollInterval: const Duration(seconds: 2),
    );

    jobToken = response.token;
    logController.text = 'Job token: $jobToken\n${logController.text}';

    // Check if we have completed jobs with images
    if (response.jobs.isNotEmpty) {
      for (var job in response.jobs) {
        final url = job.imageUrl;
        if (url != null && url.isNotEmpty) {
          logController.text = 'Image generated successfully!\n${logController.text}';
          setState(() {
            imageUrl = url;
            imageUrlRaw = url;
            sdBusy = false;
            showLog = false;
          });

          if(!isForeground) {
            notification.showNotification(
              title: '绘画',
              body: '绘画完成！',
              showAvator: false
            );
          }
          return;
        }
      }
    }

    // If we get here, no image was generated
    logController.text = 'Warning: Job completed but no image was returned\n${logController.text}';
    setState(() {
      sdBusy = false;
      showLog = true;
    });
  }

  Future<void> _makeGradioRequest(String finalPrompt) async {
    url = sdConfig.gradioUrl ?? '';
    if (url.isEmpty) {
      throw Exception('Gradio URL is not configured');
    }

    if(!url.endsWith('/')) {
      url += '/';
    }

    final dio = Dio(BaseOptions(baseUrl: url));

    // Load model if changed
    if(lastModel != sdConfig.model) {
      logController.text = '正在加载 ${sdConfig.model} ...\n${logController.text}';
      final Response response = await dio.post(
        "/gradio_api/call/load_new_model",
        data: {
          "data": [sdConfig.model, "None", "txt2img", "Automatic"],
        },
        cancelToken: cancelToken,
      );
      final data = response.data.toString();
      jobToken = data.substring(11,data.length-1);

      cancelToken = CancelToken();
      final Response<ResponseBody> loadModelQueue = await dio.get<ResponseBody>(
        "/gradio_api/call/load_new_model/$jobToken",
        options: Options(responseType: ResponseType.stream),
        cancelToken: cancelToken,
      );
      await for (var chunk in loadModelQueue.data!.stream) {
        logController.text = utf8.decode(chunk) + logController.text;
      }
      cancelToken = CancelToken();
    } else {
      logController.text = '会话已经存在\n绘画哈希值:$jobToken';
    }
    lastModel = sdConfig.model;

    logController.text = '正在绘画...\n${logController.text}';

    // Get LoRA configuration
    String? lora = await getDrawLora();
    List<String?> loraParams = List.filled(4, null);
    List<double> loraWeights = [0.33, 0.33, 0.33, 0.33];

    if (lora != null && lora.isNotEmpty) {
      final loraPattern = RegExp(r'<([^:]+):([0-9.]+)>');
      final matches = loraPattern.allMatches(lora);
      if (matches.isNotEmpty) {
        int idx = 0;
        for (var match in matches) {
          if (idx >= 4) break;
          loraParams[idx] = match.group(1);
          loraWeights[idx] = double.tryParse(match.group(2)!) ?? 0.33;
          logController.text = 'Using LoRA: ${loraParams[idx]} (weight: ${loraWeights[idx]})\n${logController.text}';
          idx++;
        }
      } else {
        loraParams[0] = lora;
        logController.text = 'Using LoRA: $lora (weight: 0.33)\n${logController.text}';
      }
    }

    // Submit generation request
    final Response response = await dio.post(
      "/gradio_api/call/sd_gen_generate_pipeline",
      data: {
        "data": [
          finalPrompt,
          sdConfig.negativePrompt,
          1,
          sdConfig.steps ?? 28,
          sdConfig.cfg ?? 7,
          true,
          -1,
          loraParams[0], // First LoRA name
          loraWeights[0], // First LoRA weight
          loraParams[1], // Second LoRA name
          loraWeights[1], // Second LoRA weight
          loraParams[2], // Third LoRA name
          loraWeights[2], // Third LoRA weight
          loraParams[3], // Fourth LoRA name
          loraWeights[3], // Fourth LoRA weight
          sdConfig.sampler,
          "Automatic",
          "Automatic",
          sdConfig.height ?? 1600,
          sdConfig.width ?? 1024,
          sdConfig.model,
          null,
          "txt2img",
          null,
          null,
          512,
          1024,
          null,
          null,
          null,
          0.55,
          100,
          200,
          1,
          1,
          1,
          9,
          1,
          0,
          1,
          false,
          "Classic",
          null,
          1.2,
          0,
          8,
          30,
          0.55,
          "Use same sampler",
          "",
          "",
          false,
          true,
          "Use same schedule type",
          -1,
          "Automatic",
          1,
          true,
          false,
          true,
          true,
          true,
          "model,seed",
          "./images",
          false,
          false,
          false,
          true,
          1,
          0.55,
          false,
          false,
          false,
          true,
          false,
          "Use same sampler",
          false,
          "",
          "",
          0.35,
          true,
          false,
          false,
          4,
          4,
          32,
          false,
          "",
          "",
          0.35,
          false,
          true,
          false,
          4,
          4,
          32,
          false,
          0,
          null,
          null,
          "plus_face",
          "original",
          0.7,
          null,
          null,
          "base",
          "style",
          0.7,
          0,
          null,
          1,
          0.5,
          false,
          false,
          59
        ],
      },
      cancelToken: cancelToken,
    );

    cancelToken = CancelToken();
    final data = response.data.toString();
    jobToken = data.substring(11,data.length-1);

    // Inference queue
    final Response<ResponseBody> inferQueue = await dio.get<ResponseBody>(
      "/gradio_api/call/sd_gen_generate_pipeline/$jobToken",
      options: Options(responseType: ResponseType.stream),
      cancelToken: cancelToken,
    );

    String lastUrl = '';
    final regexWebp = RegExp(r'download=\\"(.+?)\\"');
    final regexPng = RegExp(r'href=\\"(.+?)\\"');

    await for (var chunk in inferQueue.data!.stream) {
      String data = utf8.decode(chunk);
      logController.text = data + logController.text;
      final match = regexWebp.allMatches(data);
      if (match.isNotEmpty) {
        lastUrl = match.last.group(1)!;
      }
      if (data.contains('COMPLETE')) {
        if(lastUrl.isEmpty) return;
        if(!mounted) return;

        // Try to get PNG URL too
        String? pngUrl;
        Match? pngMatch = regexPng.firstMatch(data);
        if(pngMatch != null) {
          pngUrl = pngMatch.group(1)?.replaceAll('\\"', '');
        }

        setState(() {
          imageUrl = "${url}gradio_api/file=images/$lastUrl";
          imageUrlRaw = pngUrl != null ? url + pngUrl : imageUrl;
          sdBusy = false;
          showLog = false;
        });

        if(!isForeground) {
          notification.showNotification(
            title: '绘画',
            body: '绘画完成！',
            showAvator: false
          );
        }
        return;
      }
    }

    cancelToken = CancelToken();

    if (imageUrl == null) {
      throw Exception('Generation completed but no image URL was received');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if(state == AppLifecycleState.resumed) {
      isForeground = true;
    } else {
      isForeground = false;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    if (widget.initialImageUrl != null) {
      imageUrl = widget.initialImageUrl;
      imageUrlRaw = widget.initialImageUrl;
    }
    if (widget.promptForRedraw != null) {
      promptController.text = widget.promptForRedraw!;
    }

    if (widget.msg != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          buildPrompt();
        }
      });
    }

    getSdConfig().then((memConfig) {
      if (mounted) {
        setState(() {
          sdConfig = memConfig;
        });
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    cancelToken.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        padding: const EdgeInsets.all(16.0),
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 800),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            if (imageUrl == null) ...[
              TextField(
                controller: promptController,
                decoration: InputDecoration(
                  labelText: gptBusy ? I18n.t('generating_prompt') : I18n.t('prompt'),
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: gptBusy || sdBusy ? null : buildPrompt,
                    tooltip: I18n.t('regenerate_prompt'),
                  ),
                ),
                maxLines: 5,
                minLines: 3,
                enabled: !gptBusy && !sdBusy,
              ),
              const SizedBox(height: 8),
              if (sdBusy || showLog)
                TextField(
                  controller: logController,
                  maxLines: 5,
                  minLines: 3,
                  readOnly: true,
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    labelText: I18n.t('log'),),
                  style: const TextStyle(fontSize: 12),
                ),
            ] else ...[
              Expanded(
                child: GestureDetector(
                  onLongPress: () {
                    launchUrlString(imageUrlRaw ?? imageUrl!);
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      imageUrl!,
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                                : null,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (imageUrl == null) ...[
                  if (sdBusy)
                    TextButton(
                      onPressed: () {
                        cancelToken.cancel();
                        cancelToken = CancelToken();
                        setState(() {
                          sdBusy = false;
                          showLog = false;
                        });
                      },
                      child: Text(I18n.t('cancel')),
                    )
                  else ...[
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(I18n.t('cancel')),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: gptBusy || promptController.text.isEmpty
                          ? null
                          : () {
                              Navigator.pop(context, {
                                'action': 'start',
                                'prompt': promptController.text,
                                'sdConfig': sdConfig,
                              });
                            },
                      child: Text(I18n.t('start')),
                    ),
                  ],
                ] else ...[
                  TextButton(
                    onPressed: () {
                      setState(() {
                        imageUrl = null;
                      });
                    },
                    child: Text(I18n.t('back')),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context, {
                        'action': 'redraw',
                        'prompt': promptController.text,
                        'sdConfig': sdConfig,
                      });
                    },
                    child: Text(I18n.t('redraw')),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context, imageUrl);
                    },
                    child: Text(I18n.t('use')),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
