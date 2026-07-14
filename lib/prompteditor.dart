import 'dart:async';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:dio/dio.dart';
import 'package:http/http.dart' as http;
import 'storage.dart';
import 'i18n.dart';
import 'openai.dart';

class PromptEditor extends StatefulWidget {
  const PromptEditor({super.key});

  @override
  PromptEditorState createState() => PromptEditorState();
}

class PromptEditorState extends State<PromptEditor> {
  TextEditingController controller = TextEditingController();
  TextEditingController studentNameController = TextEditingController();
  TextEditingController originMsgController = TextEditingController();
  TextEditingController studentAvatarController = TextEditingController();
  TextEditingController drawCharPromptController = TextEditingController();
  TextEditingController vitsPromptController = TextEditingController();
  TextEditingController drawLoraController = TextEditingController();

  @override
  void initState() {
    super.initState();
    getPrompt().then((String value) {
      setState(() {
        controller.text = value;
      });
    });
    getAvatar().then((String value) {
      setState(() {
        studentAvatarController.text = value;
      });
    });
    getStudentName().then((String value) {
      setState(() {
        studentNameController.text = value;
      });
    });
    getOriginalMsg().then((String value) {
      setState(() {
        originMsgController.text = value;
      });
    });
    getDrawCharPrompt().then((String value) {
      setState(() {
        drawCharPromptController.text = value;
      });
    });
    getVitsPrompt().then((String value) {
      setState(() {
        vitsPromptController.text = value;
      });
    });
    getDrawLora().then((String value) {
      setState(() {
        drawLoraController.text = value;
      });
    });
  }

  Future<void> _pickAvatar() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['png', 'jpg', 'jpeg', 'webp', 'bmp']
    );

    if (result != null && result.files.single.bytes != null) {
      if (result.files.single.size > 1024 * 1024) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: Text(I18n.t('hint')),
                content: Text(I18n.t('image_size_limit')),
                actions: <Widget>[
                  TextButton(
                    child: Text(I18n.t('confirm')),
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              );
            },
          );
        }
        return;
      }

      String base64Image = base64Encode(result.files.single.bytes!);
      final base64String = 'data:image/${result.files.single.extension};base64,$base64Image';
      setState(() {
        studentAvatarController.text = base64String;
      });
    }
  }

  Future<void> _showEditDialog(BuildContext context, String title,
      TextEditingController controller, {bool multiLine = false}) async {
    final TextEditingController dialogController =
        TextEditingController(text: controller.text);
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('${I18n.t('edit_title')}$title'),
          content: TextField(
            controller: dialogController,
            maxLines: multiLine ? 5 : 1,
            autofocus: true,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              labelText: title,
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text(I18n.t('cancel')),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text(I18n.t('confirm')),
              onPressed: () {
                setState(() {
                  controller.text = dialogController.text;
                });
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  /// 抓取网页内容（Web 端通过多个 CORS Proxy fallback）
  Future<String> _fetchWebContent(String url) async {
    try {
      final bool isWeb = kIsWeb;
      String body = '';

      if (isWeb) {
        // Web 端：多个 CORS Proxy 轮询
        final proxies = [
          'https://corsproxy.io/?',
          'https://api.allorigins.win/raw?url=',
          'https://corsproxy.org/?',
        ];

        for (final proxy in proxies) {
          try {
            final encodedUrl = Uri.encodeComponent(url);
            final proxyUri = Uri.parse('$proxy$encodedUrl');
            final response = await http.get(
              proxyUri,
              headers: {
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
              },
            ).timeout(const Duration(seconds: 5));
            if (response.body.isNotEmpty && response.body.length > 200) {
              body = response.body;
              break;
            }
          } catch (e) {
            debugPrint('Proxy $proxy failed: $e');
            continue;
          }
        }

        // 所有代理都失败
        if (body.isEmpty) {
          debugPrint('All CORS proxies failed for URL: $url');
          return '';
        }
      } else {
        // 原生端直接请求
        final dio = Dio();
        final response = await dio.get(
          url,
          options: Options(
            responseType: ResponseType.plain,
            headers: {
              'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
            },
          ),
        );
        body = response.data.toString();
      }

      // 简单提取文本内容，去除 HTML 标签
      final RegExp tagRegex = RegExp(r'<[^>]*>', multiLine: true);
      body = body.replaceAll(tagRegex, ' ');
      body = body.replaceAll(RegExp(r'\s+'), ' ').trim();
      if (body.length > 8000) {
        body = body.substring(0, 8000);
      }
      return body;
    } catch (e) {
      debugPrint('_fetchWebContent error: $e');
      return '';
    }
  }

  /// AI 生成角色卡对话框
  void _showAiGenerateDialog(BuildContext context) {
    final TextEditingController inputController = TextEditingController();
    bool isUrlMode = false;

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Row(
                children: [
                  const Icon(Icons.auto_awesome, size: 24),
                  const SizedBox(width: 8),
                  Text(I18n.t('character_editor')),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(isUrlMode ? '📄 网页模式' : '✏️ 文本模式'),
                        const Spacer(),
                        TextButton.icon(
                          icon: Icon(isUrlMode ? Icons.edit : Icons.link),
                          label: Text(isUrlMode ? '切换文本' : '切换网页'),
                          onPressed: () {
                            setDialogState(() {
                              isUrlMode = !isUrlMode;
                              inputController.clear();
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: inputController,
                      maxLines: isUrlMode ? 1 : 5,
                      decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        hintText: isUrlMode
                            ? '输入网页 URL（如 https://zh.moegirl.org.cn/...）'
                            : '输入角色描述（性格、背景、外貌等）',
                        labelText: isUrlMode ? 'URL' : '描述',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '提示：LoRA 和语音样本不会被覆盖',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  child: Text(I18n.t('cancel')),
                  onPressed: () => Navigator.of(dialogContext).pop(),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.auto_awesome, size: 18),
                  label: Text(I18n.t('confirm')),
                  onPressed: () async {
                    final input = inputController.text.trim();
                    if (input.isEmpty) return;

                    Navigator.of(dialogContext).pop();
                    _aiGenerate(context, input, isUrlMode);
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// 执行 AI 生成
  Future<void> _aiGenerate(
      BuildContext context, String input, bool isUrlMode) async {
    // 显示 loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Text('AI 正在生成角色卡...'),
            ],
          ),
        );
      },
    );

    // 超时保护：60 秒后自动关 loading 并报错
    bool completed = false;
    Future.delayed(const Duration(seconds: 60), () {
      if (!completed && context.mounted) {
        try {
          Navigator.of(context, rootNavigator: true).pop(); // 关 loading
        } catch (_) {}
        showDialog(
          context: context,
          builder: (c) => AlertDialog(
            title: Text(I18n.t('hint')),
            content: const Text('AI 生成超时（60秒），请检查 API 连接或稍后重试'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(c).pop(),
                child: Text(I18n.t('confirm')),
              ),
            ],
          ),
        );
      }
    });

    try {
      String userContent = input;

      // URL 模式：先抓取网页
      if (isUrlMode) {
        final webContent = await _fetchWebContent(input);
        if (webContent.isEmpty) {
          completed = true;
          if (context.mounted) Navigator.of(context).pop(); // 关 loading
          if (context.mounted) {
            showDialog(
              context: context,
              builder: (c) => AlertDialog(
                title: Text(I18n.t('hint')),
                content: const Text('无法抓取网页内容，请检查 URL 是否正确'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(c).pop(),
                    child: Text(I18n.t('confirm')),
                  ),
                ],
              ),
            );
          }
          return;
        }
        userContent = webContent;
      }

      debugPrint('[AI Generate] 即将发送给 LLM 的内容长度: ${userContent.length}');
      debugPrint('[AI Generate] 内容预览前500字:\n${userContent.length > 500 ? userContent.substring(0, 500) : userContent}');

      // 获取当前 LLM 配置
      final configs = await getApiConfigs();
      if (configs.isEmpty) {
        completed = true;
        if (context.mounted) Navigator.of(context).pop();
        if (context.mounted) {
          showDialog(
            context: context,
            builder: (c) => AlertDialog(
              title: Text(I18n.t('hint')),
              content: const Text('请先在设置中配置 API'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(c).pop(),
                  child: Text(I18n.t('confirm')),
                ),
              ],
            ),
          );
        }
        return;
      }

      final config = configs.first;

      const systemPrompt = '''你是一个角色设定卡生成助手。请根据用户提供的内容，生成一个完整的角色设定卡。

请严格按照以下 JSON 格式返回，只返回 JSON，不要包含其他文字：
{
  "name": "角色名称",
  "avatar_description": "角色外貌的详细描述（中文），用于生成角色头像",
  "first_mes": "角色对用户的初次问候语或开场白，自然生动",
  "description": "完整的角色设定提示词（System Prompt），包含性格、背景故事、说话方式、兴趣爱好等，详细而完整",
  "draw_char_prompt": "用于 AI 绘图的英文 prompt，描述角色外貌特征，包含服装、发型、表情等"
}''';

      final messages = [
        ['system', systemPrompt],
        ['user', userContent],
      ];

      StringBuffer responseBuffer = StringBuffer();

      debugPrint('[AI Generate] 开始 completion 调用');
      final Completer<void> genCompleter = Completer<void>();
      completion(config, messages, (chunk) {
        responseBuffer.write(chunk);
        debugPrint('[AI Generate] 接收到 LLM chunk: $chunk');
      }, () {
        debugPrint('[AI Generate] onDone 触发');
        completed = true;
        if (context.mounted) Navigator.of(context).pop(); // 关 loading

        try {
          // 解析 JSON
          String raw = responseBuffer.toString().trim();
          // 尝试提取 ```json 代码块
          final jsonMatch = RegExp(r'```(?:json)?\s*([\s\S]*?)```').firstMatch(raw);
          if (jsonMatch != null) {
            raw = jsonMatch.group(1)!.trim();
          }
          final Map<String, dynamic> result = jsonDecode(raw);

          if (context.mounted) {
            setState(() {
              if (result['name'] != null && result['name'].toString().isNotEmpty) {
                studentNameController.text = result['name'].toString();
              }
              if (result['first_mes'] != null) {
                originMsgController.text = result['first_mes'].toString();
              }
              if (result['description'] != null) {
                controller.text = result['description'].toString();
              }
              if (result['draw_char_prompt'] != null) {
                drawCharPromptController.text = result['draw_char_prompt'].toString();
              }
            });

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('角色卡生成成功！')),
            );
          }
        } catch (e) {
          if (context.mounted) {
            showDialog(
              context: context,
              builder: (c) => AlertDialog(
                title: Text(I18n.t('hint')),
                content: Text('解析返回数据失败：$e\n\n原始返回：\n${responseBuffer.toString().substring(0, responseBuffer.toString().length.clamp(0, 500))}'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(c).pop(),
                    child: Text(I18n.t('confirm')),
                  ),
                ],
              ),
            );
          }
        }
        genCompleter.complete();
      }, (err) {
        // onErr
        completed = true;
        if (context.mounted) Navigator.of(context).pop(); // 关 loading
        if (context.mounted) {
          showDialog(
            context: context,
            builder: (c) => AlertDialog(
              title: Text(I18n.t('hint')),
              content: Text('API 调用失败：$err'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(c).pop(),
                  child: Text(I18n.t('confirm')),
                ),
              ],
            ),
          );
        }
        genCompleter.complete();
      });
      await genCompleter.future;
    } catch (e) {
      completed = true;
      if (context.mounted) Navigator.of(context).pop(); // 关 loading
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (c) => AlertDialog(
            title: Text(I18n.t('hint')),
            content: Text('出错：$e'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(c).pop(),
                child: Text(I18n.t('confirm')),
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(I18n.t('character_editor')),
        actions: [
          // AI 生成
          IconButton(
            icon: const Icon(Icons.auto_awesome),
            tooltip: 'AI 生成角色卡',
            onPressed: () => _showAiGenerateDialog(context),
          ),
          // 初始化
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              controller.text = await getPrompt(isDefault: true);
              studentNameController.text = await getStudentName(isDefault: true);
              originMsgController.text = await getOriginalMsg(isDefault: true);
              studentAvatarController.text = await getAvatar(isDefault: true);
              drawCharPromptController.text = await getDrawCharPrompt(isDefault: true);
              vitsPromptController.text = await getVitsPrompt(isDefault: true);
              drawLoraController.text = await getDrawLora(isDefault: true);
              setState(() {});
            },
          ),
          // 保存
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: () {
              setPrompt(controller.text);
              setStudentName(studentNameController.text);
              setOriginalMsg(originMsgController.text);
              setAvatar(studentAvatarController.text);
              setDrawCharPrompt(drawCharPromptController.text);
              setVitsPrompt(vitsPromptController.text);
              setDrawLora(drawLoraController.text);
              Navigator.pop(context);
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(8.0),
        children: <Widget>[
          ListTile(
            title: Text(I18n.t('character_avatar')),
          ),
          GestureDetector(
            onTap: _pickAvatar,
            child: Center(
              child: CircleAvatar(
                radius: 50,
                backgroundImage: studentAvatarController.text.startsWith('http')
                ? NetworkImage(studentAvatarController.text)
                : studentAvatarController.text.startsWith('data:image/')
                  ? MemoryImage(base64Decode(studentAvatarController.text.split(',')[1]))
                  : const AssetImage("assets/avatar.png")
              ),
            ),
          ),
          ListTile(
            title: Text(I18n.t('character_name')),
            subtitle: Text(
              studentNameController.text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () =>
                _showEditDialog(context, I18n.t('character_name'), studentNameController),
          ),
          ListTile(
            title: Text(I18n.t('initial_dialogue')),
            subtitle: Text(
              originMsgController.text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () => _showEditDialog(context, I18n.t('initial_dialogue'), originMsgController,
                multiLine: true),
          ),
          ListTile(
            title: Text(I18n.t('setting_prompt')),
            subtitle: Text(
              controller.text,
              maxLines: null,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontFamily: "Courier"),
            ),
            onTap: () =>
                _showEditDialog(context, I18n.t('setting_prompt'), controller, multiLine: true),
          ),
          ListTile(
            title: Text(I18n.t('draw_prompt')),
            subtitle: Text(
              drawCharPromptController.text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () => _showEditDialog(context, I18n.t('draw_prompt'), drawCharPromptController,
                multiLine: true),
          ),
          ListTile(
            title: const Text('LoRA'),
            subtitle: Text(
              drawLoraController.text.isEmpty 
                ? 'Single: urn:air:lora:civitai:123@456 | Multiple: <urn:air:lora:civitai:123@456:0.8>,<urn:air:lora:civitai:789@012:1.2>' 
                : drawLoraController.text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: drawLoraController.text.isEmpty ? Colors.grey : null,
                fontStyle: drawLoraController.text.isEmpty ? FontStyle.italic : null,
              ),
            ),
            onTap: () => _showEditDialog(context, 'LoRA (Single or <URN:weight>,<URN:weight>)', drawLoraController, multiLine: true),
          ),
          ListTile(
            title: Text(I18n.t('voice_ref')),
            subtitle: Text(
              vitsPromptController.text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () => _showEditDialog(context, I18n.t('voice_ref'), vitsPromptController,
                multiLine: true),
          ),
        ],
      ),
    );
  }
}
