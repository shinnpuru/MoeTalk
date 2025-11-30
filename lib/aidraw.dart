import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'dart:convert';
import 'utils.dart';
import 'openai.dart';
import 'notifications.dart';
import 'storage.dart';

class AiDraw extends StatefulWidget {
  final List<List<String>>? msg;
  final Config config;
  const AiDraw({super.key, required this.msg, required this.config});

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
  String? sessionHash;
  bool gptBusy = false, sdBusy = false, showLog = false;
  bool isForeground = true;
  final notification = NotificationHelper();
  CancelToken cancelToken = CancelToken();
  late SdConfig sdConfig;

  Future<void> buildPrompt() async {
    setState(() {
      gptBusy = true;
    });
    List<List<String>> messages = widget.msg?? [];
    String result = '';
    await completion(widget.config, messages,
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
        snackBarAlert(context, "出错了！$error");
      });
  }

  Future<void> makeRequest() async {
    if(url.isEmpty) {
      url = 'https://r3gm-diffusecraft.hf.space';
    }
    debugPrint(url);
    setState(() {
      sdBusy = true;
      showLog = true;
    });
    if(!url.endsWith('/')) {
      url += '/';
    }
    final dio = Dio(BaseOptions(baseUrl: url));
    if(sessionHash==null || lastModel != sdConfig.model) {
      logController.text = '$sessionHash\n${logController.text}';
      logController.text = '正在加载 ${sdConfig.model} ...\n${logController.text}';
      final Response response = await dio.post(
        "/gradio_api/call/load_new_model",
        data: {
          "data": [sdConfig.model, "None", "txt2img", "Automatic"],
        },
        cancelToken: cancelToken,
      );
      final data = response.data.toString();
      sessionHash = data.substring(11,data.length-1);
      debugPrint("/call/load_new_model/$sessionHash");
      cancelToken = CancelToken();
      final Response<ResponseBody> loadModelQueue = await dio.get<ResponseBody>(
        "/gradio_api/call/load_new_model/$sessionHash",
        options: Options(responseType: ResponseType.stream),
        cancelToken: cancelToken,
      );
      await for (var chunk in loadModelQueue.data!.stream) {
        logController.text = utf8.decode(chunk) + logController.text;
      }
      cancelToken = CancelToken();
    } else {
      logController.text = '会话已经存在\n绘画哈希值:$sessionHash';
    }
    lastModel = sdConfig.model;
    logController.text = '正在绘画...\n${logController.text}';
    if(!sdConfig.prompt.contains("CHAR")){
      sdConfig.prompt+= ", CHAR";
    }
    if(!sdConfig.prompt.contains("VERB")){
      sdConfig.prompt+= ", VERB";
    }
    String? charPrompt = await getDrawCharPrompt();
    String finalPrompt = sdConfig.prompt.replaceAll("VERB", promptController.text).replaceAll("CHAR", charPrompt);
    debugPrint(finalPrompt);
    final Response response = await dio.post(
      "/gradio_api/call/sd_gen_generate_pipeline",
      data: {
        "data": [
          finalPrompt,
          sdConfig.negativePrompt,
          1,
          sdConfig.steps,
          7,
          true,
          -1,
          null,
          0.33,
          null,
          0.33,
          null,
          0.33,
          null,
          0.33,
          null,
          0.33,
          null,
          0.33,
          null,
          0.33,
          sdConfig.sampler,
          "Automatic",
          "Automatic",
          sdConfig.height??1600,
          sdConfig.width??1024,
          sdConfig.model,
          null,//"vaes/sdxl_vae-fp16fix-c-1.1-b-0.5.safetensors",
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
    sessionHash = data.substring(11,data.length-1);
    debugPrint("/call/sd_gen_generate_pipeline/$sessionHash");

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
      logController.text = data + logController.text;
      final match = regexWebp.allMatches(data);
      debugPrint(match.toString());
      if (match.isNotEmpty) {
        lastUrl = match.last.group(1)!;
      }
      if (data.contains('COMPLETE')) {
        if(lastUrl.isEmpty) return;
        if(!mounted) return;
        setState(() {
          imageUrl = "${url}gradio_api/file=images/$lastUrl";
          debugPrint(imageUrl);
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
      }
      if (data.contains('COMPLETE')) {
          Match? match = regexPng.firstMatch(data);
          String? filePath = match?.group(1)?.replaceAll('\\"', '');
          if(filePath != null) {
            imageUrlRaw = url + filePath;
          }
          debugPrint(imageUrlRaw);
      }
    }
    cancelToken = CancelToken();
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
    getDrawUrl().then((value) {
      debugPrint('Fetched draw URL: $value');
      if (mounted) {
        setState(() {
          url = value ?? '';
        });
      }
    });
    // debugPrint(url); // This would print the initial empty 'url'

    if (widget.msg != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          buildPrompt();
        }
      });
    }

    getSdConfig().then((memConfig) {
      if (mounted) {
        // Assuming sdConfig might be used in a way that doesn't require setState here,
        // or its update is handled elsewhere if it needs to trigger a rebuild.
        sdConfig = memConfig;
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
                  labelText: gptBusy ? '生成提示词中...' : '提示词',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: gptBusy || sdBusy ? null : buildPrompt,
                    tooltip: '重新生成提示词',
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
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: '日志',),
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
                      child: const Text('取消'),
                    )
                  else ...[
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('取消'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: gptBusy || promptController.text.isEmpty
                          ? null
                          : () {
                              makeRequest().catchError((e) {
                                snackBarAlert(context, "error! $e");
                                setState(() {
                                  sdBusy = false;
                                });
                              });
                            },
                      child: const Text('开始'),
                    ),
                  ],
                ] else ...[
                  TextButton(
                    onPressed: () {
                      setState(() {
                        imageUrl = null;
                      });
                    },
                    child: const Text('返回'),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () {
                      makeRequest().catchError((e) {
                        snackBarAlert(context, "error! $e");
                        setState(() {
                          sdBusy = false;
                        });
                      });
                    },
                    child: const Text('重绘'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context, imageUrl);
                    },
                    child: const Text('使用'),
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
