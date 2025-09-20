import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:uuid/uuid.dart';
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
    String prompt = '''system instruction:暂停角色扮演，你的任务是根据当前的角色的状态，生成一系列提示词，以指导扩散模型生成图像。提示词应该是一系列描述性的英语单词或短语，能够引导模型生成符合描述的图像，具体来说，是danbooru数据集中的标签。提示词用逗号分隔，没有换行。你的回复必须仅包含图片描述，不要包含任何其他说明等内容。画风应该是二次元风格，但不需要在提示词中写明画风。不要加入1girl, masterpiece等过于宽泛的词汇。示例：blue sky, cake stand, capelet, chest harness, cloud, cloudy sky, cup, day, dress, flower, food, hair flower, hair ornament, harness, holding, holding cup, leaf, looking at viewer, neckerchief, chair, sitting, sky, solo, table。请先总结当前的场景、视角、构图、服装、动作、表情等描述画面的详细内容，然后在||后面输出提示词。''';
    messages.add(['user', prompt]);
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
      sessionHash = const Uuid().v4();
      logController.text = '$sessionHash\n${logController.text}';
      logController.text = '正在加载 ${sdConfig.model} ...\n${logController.text}';
      await dio.post(
        "/queue/join",
        data: {
          "data": [sdConfig.model, "None", "txt2img", "Automatic"],
          "fn_index": 13,
          "session_hash": sessionHash,
        },
        cancelToken: cancelToken,
      );
      cancelToken = CancelToken();
      final Response<ResponseBody> loadModelQueue = await dio.get<ResponseBody>(
        "/queue/data",
        queryParameters: {"session_hash": sessionHash},
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
    if(!sdConfig.prompt.contains("VERB")){
      sdConfig.prompt+= ", VERB";
    }
    await dio.post(
      "/queue/join",
      data: {
        "data": [
          sdConfig.prompt.replaceAll("VERB", promptController.text),
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
          0.1,
          0.1,
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
        "fn_index": 14,
        "session_hash": sessionHash,
      },
      cancelToken: cancelToken,
    );
    cancelToken = CancelToken();
    // Inference queue
    final Response<ResponseBody> inferQueue = await dio.get<ResponseBody>(
      "/queue/data",
      queryParameters: {"session_hash": sessionHash},
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
      if (data.contains('close_stream')) {
        if(lastUrl.isEmpty) return;
        if(!mounted) return;
        setState(() {
          imageUrl = "${url}file=images/$lastUrl";
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
      if (data.contains('GENERATION DATA')) {
          Match? match = regexPng.firstMatch(data);
          String? filePath = match?.group(0)?.replaceAll('\\"', '');
          if(filePath != null) {
            imageUrlRaw = url + filePath;
          }
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
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            onPressed: () {
              setState(() {
                showLog = !showLog;
              });
            },
            icon: Icon(showLog?Icons.image:Icons.assignment)
          ),
          IconButton(
            onPressed: () {
              Navigator.pop(context,imageUrl);
            },
            icon: const Icon(Icons.arrow_forward)
          )
        ],
        title: const Text('绘画'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [            
            TextField(
              controller: promptController,
              decoration: InputDecoration(labelText: gptBusy?'生成中...':'提示词'),
              maxLines: 3,
              minLines: 1,
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () {
                    if(gptBusy) return;
                    buildPrompt();
                  },
                  child: const Text('重新提示'),
                ),
                const SizedBox(width: 5),
                ElevatedButton(
                  onPressed: () {
                    if(sdBusy) return;
                    makeRequest().catchError((e) {
                      snackBarAlert(context, "error! $e");
                    });
                  },
                  child: Text(sdBusy?'处理中...':'开始绘画' ),
                ),
                const SizedBox(width: 5),
                // CancelButton
                ElevatedButton(
                  onPressed: () {
                    cancelToken.cancel();
                    cancelToken = CancelToken();
                    sessionHash = null;
                    logController.text = '';
                    setState(() {
                      gptBusy = false;
                      sdBusy = false;
                    });
                  },
                  child: const Text('取消绘画'),
                ),
              ]
            ),
            const SizedBox(height: 8),
            Expanded(
              child: (imageUrl == null) || showLog
                ? TextField(
                    controller: logController,
                    maxLines: null,
                    readOnly: true,
                    decoration: const InputDecoration(border: InputBorder.none),
                    expands: true,
                  )
                : GestureDetector(
                    onLongPress: () {
                      launchUrlString(imageUrlRaw==null?imageUrl!:imageUrlRaw!);
                    },
                    child: Image.network(imageUrl!,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) {
                            return child;
                          } else {
                            return Center(
                              child: CircularProgressIndicator(
                                value: loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
                                    : null,
                              ),
                            );
                          }
                        }
                      )
                  )
            ),
          ],
        ),
      ),
    );
  }
}
