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

class AiDraw extends StatefulWidget {
  final List<List<String>>? msg;
  final Config config;
  final String? initialImageUrl;
  final String? initialPrompt;
  const AiDraw({super.key, required this.msg, required this.config, this.initialImageUrl, this.initialPrompt});

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

  Future<String?> makeRequest() async {
    if (mounted) {
      setState(() {
        sdBusy = true;
        showLog = true;
      });
    }

    try {
      // Initialize Civitai client if API token is available
      if (sdConfig.civitaiApiToken == null || sdConfig.civitaiApiToken!.isEmpty) {
        throw Exception('Civitai API token is not configured');
      }

      civitaiClient = CivitaiClient(apiToken: sdConfig.civitaiApiToken!);
      
      logController.text = 'Initializing Civitai API...\n${logController.text}';
      
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
      
      debugPrint('Final prompt: $finalPrompt');
      logController.text = 'Generating image with prompt:\n$finalPrompt\n${logController.text}';
      
      // Get LoRA configuration
      String? lora = await getDrawLora();
      Map<String, dynamic>? additionalNetworks;
      if (lora != null && lora.isNotEmpty) {
        // Parse LoRA configuration
        // Format 1: <AIR1:weight1>,<AIR2:weight2> for multiple LoRAs
        // Format 2: Single LoRA URN with weight 1.0
        
        final loraPattern = RegExp(r'<([^:]+):([0-9.]+)>');
        final matches = loraPattern.allMatches(lora);
        
        if (matches.isNotEmpty) {
          // Multiple LoRA format: <AIR1:weight1>,<AIR2:weight2>
          additionalNetworks = {};
          for (var match in matches) {
            String airUrn = match.group(1)!;
            double weight = double.tryParse(match.group(2)!) ?? 1.0;
            additionalNetworks[airUrn] = {'strength': weight};
            logController.text = 'Using LoRA: $airUrn (weight: $weight)\n${logController.text}';
          }
        } else {
          // Single LoRA format with weight 1.0
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
            if (mounted) {
              setState(() {
                imageUrl = url;
                imageUrlRaw = url;
                sdBusy = false;
                showLog = false;
              });
            }
            
            if(!isForeground) {
              notification.showNotification(
                title: '绘画',
                body: '绘画完成！',
                showAvator: false
              );
            }
            return url;
          }
        }
      }

      // If we get here, no image was generated
      logController.text = 'Warning: Job completed but no image was returned\n${logController.text}';
      if (mounted) {
        setState(() {
          sdBusy = false;
          showLog = true;
        });
      }
      return null;
    } catch (e) {
      debugPrint('Error during image generation: $e');
      logController.text = 'Error: $e\n${logController.text}';
      if (mounted) {
        setState(() {
          sdBusy = false;
          showLog = true;
        });
        snackBarAlert(context, "${I18n.t('error')} $e");
      } else {
        rethrow;
      }
      return null;
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
    if (widget.initialPrompt != null) {
      promptController.text = widget.initialPrompt!;
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
                              Navigator.pop(context, [makeRequest(), promptController.text]);
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
                      Navigator.pop(context, [makeRequest(), promptController.text]);
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