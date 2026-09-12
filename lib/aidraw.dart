import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'utils.dart';
import 'openai.dart';
import 'notifications.dart';
import 'storage.dart';
import 'i18n.dart';
import 'civitai_client.dart';
import 'generation_queue.dart';
import 'media_image.dart';
import 'sdcpp_client.dart';

Future<String?> generateImageTask({
  required String promptText,
  required SdConfig sdConfig,
}) async {
  if (sdConfig.backendType == BackendType.sdcpp) {
    return _generateImageWithSdCpp(promptText: promptText, sdConfig: sdConfig);
  } else {
    return _generateImageWithCivitai(
        promptText: promptText, sdConfig: sdConfig);
  }
}

Future<String?> _generateImageWithCivitai({
  required String promptText,
  required SdConfig sdConfig,
}) async {
  final task = GenerationQueue.instance.start(
    kind: GenerationKind.drawing,
    backend: 'Civitai',
    title: promptText,
  );
  try {
    if (sdConfig.civitaiApiToken == null || sdConfig.civitaiApiToken!.isEmpty) {
      throw Exception('Civitai API token is not configured');
    }

    final civitaiClient = CivitaiClient(apiToken: sdConfig.civitaiApiToken!);

    String prompt = sdConfig.prompt;
    if (!prompt.contains("CHAR")) {
      prompt += ", CHAR";
    }
    if (!prompt.contains("VERB")) {
      prompt += ", VERB";
    }
    String? charPrompt = await getDrawCharPrompt();
    String finalPrompt =
        prompt.replaceAll("VERB", promptText).replaceAll("CHAR", charPrompt);

    task.note('${I18n.t('generation_note_model')}: ${sdConfig.model}');

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
          task.note('${I18n.t('sdcpp_lora')}: $airUrn ($weight)');
        }
      } else {
        additionalNetworks = {
          lora: {'strength': 1.0},
        };
        task.note('${I18n.t('sdcpp_lora')}: $lora (1.0)');
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

    task.running(
      detail: '${sdConfig.width ?? 1024}x${sdConfig.height ?? 1600} · '
          '${sdConfig.steps ?? 28} steps · ${sdConfig.sampler}',
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
          task.note('${I18n.t('generation_note_image')}: $url');
          task.complete();
          return url;
        }
      }
    }
    task.fail('no image was returned for the finished job');
    return null;
  } catch (error) {
    task.fail(error);
    rethrow;
  }
}

/// Everything required to run one sd.cpp generation request.
class _SdCppPlan {
  final SdCppClient client;
  final SdCppCapabilities capabilities;
  final SdCppImageRequest request;
  final List<String> notes;

  const _SdCppPlan({
    required this.client,
    required this.capabilities,
    required this.request,
    required this.notes,
  });
}

Future<String?> _generateImageWithSdCpp({
  required String promptText,
  required SdConfig sdConfig,
}) async {
  final task = GenerationQueue.instance.start(
    kind: GenerationKind.drawing,
    backend: 'sd.cpp',
    title: promptText,
  );
  try {
    String prompt = sdConfig.prompt;
    if (!prompt.contains("CHAR")) {
      prompt += ", CHAR";
    }
    if (!prompt.contains("VERB")) {
      prompt += ", VERB";
    }
    String? charPrompt = await getDrawCharPrompt();
    String finalPrompt =
        prompt.replaceAll("VERB", promptText).replaceAll("CHAR", charPrompt);

    final plan = await _prepareSdCppPlan(
      sdConfig: sdConfig,
      finalPrompt: finalPrompt,
    );
    for (final note in plan.notes) {
      debugPrint('sd.cpp: $note');
      task.note(note);
    }

    task.running(detail: _sdCppPlanDetail(plan.request));
    final jobId = await plan.client.submitImage(plan.request);
    task.note('${I18n.t('generation_note_job')}: $jobId');

    final job = await plan.client.waitForJob(
      jobId,
      pollInterval: const Duration(seconds: 1),
      onUpdate: (job) => task.running(detail: _sdCppStatusDetail(job)),
    );
    final image = _firstSdCppImage(job);
    final reference = await storeGeneratedMediaImage(
      image.bytes,
      image.extension,
    );
    task.complete(
      detail: '${plan.request.width}x${plan.request.height} · '
          '${(image.bytes.length / 1024).round()} KB',
    );
    return reference;
  } catch (error) {
    if (error is SdCppCancelledException) {
      task.cancel();
    } else {
      task.fail(error);
    }
    rethrow;
  }
}

/// `832x1216 · 28 steps · dpm++2m/karras` for the task list.
String _sdCppPlanDetail(SdCppImageRequest request) =>
    '${request.width}x${request.height} · ${request.steps} steps · '
    '${request.sampleMethod ?? 'default'}/${request.scheduler ?? 'default'}';

/// Queue position while waiting, plain "running" afterwards.
String _sdCppStatusDetail(SdCppJob job) {
  if (job.status == 'queued') {
    final position = job.queuePosition;
    if (position == null || position <= 0) {
      return I18n.t('generation_status_queued');
    }
    return '${I18n.t('generation_status_queued')} #$position';
  }
  return I18n.t('generation_status_running');
}

SdCppJobImage _firstSdCppImage(SdCppJob job) {
  if (job.images.isEmpty) {
    throw const SdCppException('generation finished without an image');
  }
  return job.images.first;
}

/// Builds the sd.cpp request from the app configuration and the server
/// capabilities, collecting log lines for the drawing dialog.
Future<_SdCppPlan> _prepareSdCppPlan({
  required SdConfig sdConfig,
  required String finalPrompt,
}) async {
  final client = SdCppClient(baseUrl: sdConfig.sdCppBaseUrl);
  final capabilities = await client.fetchCapabilities();
  if (!capabilities.supportsImageGeneration) {
    throw SdCppException(I18n.t('sd_cpp_no_image_mode'));
  }

  final notes = <String>[
    '${I18n.t('sdcpp_model')}: ${capabilities.displayModel}',
  ];

  final sampler = resolveSdCppSampler(
    sdConfig.sampler,
    availableMethods: capabilities.samplers,
    availableSchedulers: capabilities.schedulers,
  );
  if (sampler.unsupportedSampler != null) {
    notes.add('${I18n.t('sdcpp_sampler_unsupported')}'
        ' (${sampler.unsupportedSampler})');
  }
  if (sampler.ignoredScheduler != null) {
    notes.add('${I18n.t('sdcpp_scheduler_ignored')}'
        ' (${sampler.ignoredScheduler})');
  }

  final loras = resolveSdCppLoras(
    await getDrawLora(),
    availableLoras: capabilities.loras,
    onSkip: (name) => notes.add('${I18n.t('sdcpp_lora_skipped')}: $name'),
    onResolved: (lora, name) =>
        notes.add('${I18n.t('sdcpp_lora')}: $name (${lora.multiplier})'),
  );

  final width = _clampSdCppDimension(
    sdConfig.width ?? 1024,
    capabilities.minWidth,
    capabilities.maxWidth,
    notes,
  );
  final height = _clampSdCppDimension(
    sdConfig.height ?? 1600,
    capabilities.minHeight,
    capabilities.maxHeight,
    notes,
  );
  final steps = (sdConfig.steps ?? 25).clamp(1, 200).toInt();

  final request = SdCppImageRequest(
    prompt: finalPrompt,
    negativePrompt: sdConfig.negativePrompt,
    width: width,
    height: height,
    steps: steps,
    cfgScale: (sdConfig.cfg ?? 5).toDouble(),
    // sd.cpp reads a negative seed as "pick a random seed".
    seed: sdConfig.seed ?? -1,
    clipSkip: sdConfig.clipSkip,
    sampleMethod: sampler.sampleMethod,
    scheduler: sampler.scheduler,
    loras: loras,
  );

  notes.add('${sampler.sampleMethod ?? 'default'}'
      ' / ${sampler.scheduler ?? 'default'}'
      ' · ${request.width}x${request.height}'
      ' · ${request.steps} steps · cfg ${request.cfgScale}');

  return _SdCppPlan(
    client: client,
    capabilities: capabilities,
    request: request,
    notes: notes,
  );
}

int _clampSdCppDimension(
  int value,
  int? minimum,
  int? maximum,
  List<String> notes,
) {
  var result = value;
  if (minimum != null && result < minimum) result = minimum;
  if (maximum != null && result > maximum) result = maximum;
  if (result != value) {
    notes.add('${I18n.t('sdcpp_size_clamped')}: $value -> $result');
  }
  return result;
}

class AiDraw extends StatefulWidget {
  final List<List<String>>? msg;
  final Config config;
  final String? initialImageUrl;
  final String? promptForRedraw;
  const AiDraw(
      {super.key,
      required this.msg,
      required this.config,
      this.initialImageUrl,
      this.promptForRedraw});

  @override
  AiDrawState createState() => AiDrawState();
}

class AiDrawState extends State<AiDraw> with WidgetsBindingObserver {
  TextEditingController descriptionController = TextEditingController();
  TextEditingController logController = TextEditingController();
  TextEditingController promptController = TextEditingController();
  String? imageUrl;
  String? imageUrlRaw;
  String? jobToken;
  bool gptBusy = false, sdBusy = false, showLog = false;
  bool isForeground = true;
  final notification = NotificationHelper();
  CancelToken cancelToken = CancelToken();
  late SdConfig sdConfig;
  CivitaiClient? civitaiClient;
  int _generationOperation = 0;
  int _promptOperation = 0;

  bool _isActiveGeneration(int operation) =>
      mounted && operation == _generationOperation;

  Future<void> buildPrompt() async {
    final operation = ++_promptOperation;
    setState(() {
      gptBusy = true;
    });
    List<List<String>> messages = widget.msg ?? [];
    String result = '';
    final Config? aidrawCfg = await getAidrawApiConfig();
    final Config configToUse = aidrawCfg ?? widget.config;
    await completion(configToUse, messages, (String data) async {
      if (!mounted || operation != _promptOperation) return;
      result += data.replaceAll("\n", " ");
      promptController.text = result
          .split('||')
          .last
          .replaceAll(RegExp(await getResponseRegex()), '');
    }, () {
      if (!mounted || operation != _promptOperation) return;
      setState(() {
        gptBusy = false;
      });
    }, (String error) {
      if (!mounted || operation != _promptOperation) return;
      setState(() {
        gptBusy = false;
      });
      logController.text = '$error\n${logController.text}';
      snackBarAlert(context, "${I18n.t('error')} $error");
    });
  }

  Future<void> makeRequest() async {
    final operation = ++_generationOperation;
    setState(() {
      sdBusy = true;
      showLog = true;
    });

    try {
      // Prepare prompt
      if (!sdConfig.prompt.contains("CHAR")) {
        sdConfig.prompt += ", CHAR";
      }
      if (!sdConfig.prompt.contains("VERB")) {
        sdConfig.prompt += ", VERB";
      }
      String? charPrompt = await getDrawCharPrompt();
      String finalPrompt = sdConfig.prompt
          .replaceAll("VERB", promptController.text)
          .replaceAll("CHAR", charPrompt);

      logController.text =
          'Generating image with prompt:\n$finalPrompt\n${logController.text}';

      if (sdConfig.backendType == BackendType.sdcpp) {
        await _makeSdCppRequest(finalPrompt, operation);
      } else {
        await _makeCivitaiRequest(finalPrompt, operation);
      }
    } catch (e) {
      if (!_isActiveGeneration(operation)) return;
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

  Future<void> _makeCivitaiRequest(String finalPrompt, int operation) async {
    final task = GenerationQueue.instance.start(
      kind: GenerationKind.drawing,
      backend: 'Civitai',
      title: promptController.text.isNotEmpty
          ? promptController.text
          : finalPrompt,
    );
    try {
      // Initialize Civitai client if API token is available
      if (sdConfig.civitaiApiToken == null ||
          sdConfig.civitaiApiToken!.isEmpty) {
        throw Exception('Civitai API token is not configured');
      }

      civitaiClient = CivitaiClient(apiToken: sdConfig.civitaiApiToken!);

      logController.text =
          'Initializing Civitai API...\n${logController.text}';
      task.note('${I18n.t('generation_note_model')}: ${sdConfig.model}');

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
            logController.text =
                'Using LoRA: $airUrn (weight: $weight)\n${logController.text}';
            task.note('${I18n.t('sdcpp_lora')}: $airUrn ($weight)');
          }
        } else {
          additionalNetworks = {
            lora: {'strength': 1.0},
          };
          logController.text =
              'Using LoRA: $lora (weight: 1.0)\n${logController.text}';
          task.note('${I18n.t('sdcpp_lora')}: $lora (1.0)');
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

      logController.text =
          'Submitting job to Civitai...\n${logController.text}';
      task.running(
        detail: '${sdConfig.width ?? 1024}x${sdConfig.height ?? 1600} · '
            '${sdConfig.steps ?? 28} steps · ${sdConfig.sampler}',
      );

      // Submit the job and wait for completion
      final response = await civitaiClient!.image.create(
        input: input,
        wait: true,
        timeout: const Duration(minutes: 10),
        pollInterval: const Duration(seconds: 2),
      );
      if (!_isActiveGeneration(operation)) {
        task.cancel(detail: I18n.t('generation_status_cancelled'));
        return;
      }

      jobToken = response.token;
      logController.text = 'Job token: $jobToken\n${logController.text}';
      task.note('${I18n.t('generation_note_job')}: $jobToken');

      // Check if we have completed jobs with images
      if (response.jobs.isNotEmpty) {
        for (var job in response.jobs) {
          final url = job.imageUrl;
          if (url != null && url.isNotEmpty) {
            logController.text =
                'Image generated successfully!\n${logController.text}';
            task.note('${I18n.t('generation_note_image')}: $url');
            task.complete();
            setState(() {
              imageUrl = url;
              imageUrlRaw = url;
              sdBusy = false;
              showLog = false;
            });

            if (!isForeground) {
              notification.showNotification(
                  title: '绘画', body: '绘画完成！', showAvator: false);
            }
            return;
          }
        }
      }

      // If we get here, no image was generated
      task.fail('no image was returned for the finished job');
      logController.text =
          'Warning: Job completed but no image was returned\n${logController.text}';
      setState(() {
        sdBusy = false;
        showLog = true;
      });
    } catch (error) {
      task.fail(error);
      rethrow;
    }
  }

  /// Generates an image with a stable-diffusion.cpp server, keeping the queue
  /// status in the first log line while the job runs.
  Future<void> _makeSdCppRequest(String finalPrompt, int operation) async {
    final stopwatch = Stopwatch()..start();
    String statusLine = '';
    final task = GenerationQueue.instance.start(
      kind: GenerationKind.drawing,
      backend: 'sd.cpp',
      title: promptController.text.isNotEmpty
          ? promptController.text
          : finalPrompt,
    );

    void setStatus(String text) {
      if (!_isActiveGeneration(operation)) return;
      if (statusLine.isEmpty) {
        logController.text = '$text\n${logController.text}';
      } else {
        logController.text = logController.text.replaceFirst(statusLine, text);
      }
      statusLine = text;
    }

    String elapsed() =>
        '${(stopwatch.elapsedMilliseconds / 1000).toStringAsFixed(1)}s';

    try {
      setStatus(I18n.t('sdcpp_connecting'));

      final plan = await _prepareSdCppPlan(
        sdConfig: sdConfig,
        finalPrompt: finalPrompt,
      );
      for (final note in plan.notes) {
        task.note(note);
      }
      if (!_isActiveGeneration(operation)) {
        task.cancel(detail: I18n.t('generation_status_cancelled'));
        return;
      }
      for (final note in plan.notes) {
        logController.text = '$note\n${logController.text}';
      }

      task.running(detail: _sdCppPlanDetail(plan.request));
      final jobId = await plan.client.submitImage(plan.request);
      task.note('${I18n.t('generation_note_job')}: $jobId');
      if (!_isActiveGeneration(operation)) {
        task.cancel(detail: I18n.t('generation_status_cancelled'));
        return;
      }
      logController.text =
          '${I18n.t('sdcpp_job')}: $jobId\n${logController.text}';

      final job = await plan.client.waitForJob(
        jobId,
        isCancelled: () =>
            !_isActiveGeneration(operation) || cancelToken.isCancelled,
        onUpdate: (job) {
          task.running(detail: _sdCppStatusDetail(job));
          if (job.status == 'queued') {
            final position =
                job.queuePosition != null ? ' #${job.queuePosition}' : '';
            setStatus('${I18n.t('sdcpp_queued')}$position (${elapsed()})');
          } else if (job.status == 'generating') {
            setStatus('${I18n.t('sdcpp_generating')} (${elapsed()})');
          }
        },
      );

      final image = _firstSdCppImage(job);
      final reference = await storeGeneratedMediaImage(
        image.bytes,
        image.extension,
      );
      task.complete(
        detail: '${plan.request.width}x${plan.request.height} · '
            '${(image.bytes.length / 1024).round()} KB',
      );
      if (!_isActiveGeneration(operation)) return;

      setStatus('${I18n.t('draw_completed')} (${elapsed()})');
      setState(() {
        imageUrl = reference;
        imageUrlRaw = reference;
        sdBusy = false;
        showLog = false;
      });

      if (!isForeground) {
        notification.showNotification(
            title: '绘画', body: '绘画完成！', showAvator: false);
      }
    } on SdCppCancelledException {
      // Cancelled by the user or by closing the dialog: nothing to report.
      task.cancel();
      return;
    } catch (error) {
      task.fail(error);
      rethrow;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
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
    _generationOperation++;
    _promptOperation++;
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
                  labelText:
                      gptBusy ? I18n.t('generating_prompt') : I18n.t('prompt'),
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
                    labelText: I18n.t('log'),
                  ),
                  style: const TextStyle(fontSize: 12),
                ),
            ] else ...[
              Expanded(
                child: GestureDetector(
                  onLongPress: () {
                    openMediaReference(imageUrlRaw ?? imageUrl!);
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: MediaImage(imageUrl!),
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
                        _generationOperation++;
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
