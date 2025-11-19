import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:typed_data';   // 用于 Uint8List
import 'package:image/image.dart' as img; // 导入 image 包并重命名，避免冲突
import 'utils.dart';
import 'package:http/http.dart' as http;
import 'dart:io' if (kIsWeb) 'dart:html' as html;
import 'non_web_utils.dart'
    if (dart.library.html) 'web_utils.dart';

// List 0:base_url 1:api_key 2:model_name 3:temperature 4:frequency_penalty 5:presence_penalty 6:max_tokens
Future<void> setApiConfig(Config config) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  List<String> configList = [config.baseUrl,config.apiKey,config.model];
  if (config.temperature != null) {
    configList.add(config.temperature!);
  } else {
    configList.add('');
  }
  if (config.frequencyPenalty != null) {
    configList.add(config.frequencyPenalty!);
  } else {
    configList.add('');
  }
  if (config.presencePenalty != null) {
    configList.add(config.presencePenalty!);
  } else {
    configList.add('');
  }
  if (config.maxTokens != null) {
    configList.add(config.maxTokens!);
  } else {
    configList.add('');
  }
  await prefs.setStringList("api_${config.name}", configList);
  debugPrint("set api ${config.name}: ${config.toString()}");
}

Future<void> setCurrentApiConfig(String name) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  await prefs.setString("current_api", "api_$name");
  debugPrint("set current api $name");
}

Future<void> deleteApiConfig(String name) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  await prefs.remove("api_$name");
  debugPrint("delete api $name");
}

Future<List<Config>> getApiConfigs() async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  List<Config> configs = [];
  String current = prefs.getString("current_api") ?? "";
  Set<String> keys = prefs.getKeys();
  if (current.isNotEmpty) {
    if (prefs.getStringList(current) == null) {
      await prefs.remove("current_api");
    } else {
      List<String> currentConfig = prefs.getStringList(current) ?? ['','','',''];
      if(currentConfig.length==3){
        configs.add(Config(name: current.replaceFirst("api_", ""), baseUrl: currentConfig[0], 
          apiKey: currentConfig[1], model: currentConfig[2]));
      } else if(currentConfig.length==7){
        configs.add(Config(name: current.replaceFirst("api_", ""), baseUrl: currentConfig[0], 
          apiKey: currentConfig[1], model: currentConfig[2], temperature: currentConfig[3],
          frequencyPenalty: currentConfig[4], presencePenalty: currentConfig[5], maxTokens: currentConfig[6]));
      }
    }
  }
  for (String key in keys) {
    if (key.startsWith("api_") && key != current) {
      List<String> currentConfig = prefs.getStringList(key) ?? ['','','',''];
      if(currentConfig.length==3){
        configs.add(Config(name: key.replaceFirst("api_", ""), baseUrl: currentConfig[0], 
          apiKey: currentConfig[1], model: currentConfig[2]));
      } else if(currentConfig.length==7){
        configs.add(Config(name: key.replaceFirst("api_", ""), baseUrl: currentConfig[0], 
          apiKey: currentConfig[1], model: currentConfig[2], temperature: currentConfig[3],
          frequencyPenalty: currentConfig[4], presencePenalty: currentConfig[5], maxTokens: currentConfig[6]));
      }
    }
  }
  debugPrint("query api configs: ${configs.toString()}");
  return configs;
}

// 0:name 1:avatar 2:first_mes 3:description 4:timestamp
Future<List<List<String>>> getStudents() async{
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  List<List<String>> students = [];
  Set<String> keys = prefs.getKeys();
  for (String key in keys) {
    if (key.startsWith("student_")) {
      students.add(prefs.getStringList(key) ?? ["","","","",""]);
    }
  }
  return students;
}

Future<void> addStudent(String name, String avatar, String firstMes, String description) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  String timeStamp = DateTime.now().millisecondsSinceEpoch.toString();
  await prefs.setStringList("student_${timeStamp}_$name", [name,avatar,firstMes,description,timeStamp]);
}

Future<void> deleteStudent(String key) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  if (prefs.containsKey(key)) {
    await prefs.remove(key);
  } else {
    debugPrint("key not found: $key");
  }
}

// 0:intro 1:timestamp 2:msg
Future<List<List<String>>> getHistorys() async{
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  List<List<String>> historys = [];
  Set<String> keys = prefs.getKeys();
  for (String key in keys) {
    if (key.startsWith("history_")) {
      String timeStamp = key.replaceFirst("history_", "");
      List<String> history = prefs.getStringList(key) ?? ["",""];
      historys.add([history[0],timeStamp,history[1]]);
    }
  }
  return historys;
}

Future<void> addHistory(String msg,String name) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  String timeStamp = DateTime.now().millisecondsSinceEpoch.toString();
  await prefs.setStringList("history_$timeStamp", [name,msg]);
}

void deleteHistory(String key) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  if (prefs.containsKey(key)) {
    await prefs.remove(key);
  } else {
    debugPrint("key not found: $key");
  }
}

void setAvatar(String imgUri) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  await prefs.setString("avatar", imgUri);
}

Future<String> getAvatar({bool isDefault=false}) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  String? avatar = prefs.getString("avatar");
  if (avatar == null || isDefault){
     return "assets/avatar.png";
  }
  return avatar;
}

void setTempHistory(String msg) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  await prefs.setString("temp_history", msg);
}

Future<String?> getTempHistory() async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  return prefs.getString("temp_history");
}

Future<String> convertToJson() async {
  final prefs = await SharedPreferences.getInstance();
  final keys = prefs.getKeys();
  
  Map<String, dynamic> allPrefs = {};
  for (String key in keys) {
    allPrefs[key] = prefs.get(key);
  }
  return jsonEncode(allPrefs);
}

Future<void> setUserName(String name) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  await prefs.setString("user_name", name);
}

Future<String> getUserName() async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  String? name = prefs.getString("user_name");
  if (name == null || name.isEmpty) {
    return "老师";
  }
  return name;
}

Future<String> getStudentName({bool isDefault=false}) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  String? name = prefs.getString("name");
  if (name == null || isDefault) {
    return "昕蒲";
  }
  return name;
}

Future<void> setStudentName(String name) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  await prefs.setString("name", name);
}

Future<String> getOriginalMsg({bool isDefault=false}) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  String? msg = prefs.getString("first_mes");
  if (msg == null || isDefault) {
    return "你好，我是昕蒲。请问有什么可以帮助你的吗？";
  }
  return msg;
}

Future<void> setOriginalMsg(String msg) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  await prefs.setString("first_mes", msg);
} 

Future<String> getPrompt({bool isDefault=false}) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  String? prompt = prefs.getString("description");
  if (prompt == null || isDefault) {
    prompt = "你是一个AI助手，名叫昕蒲。你可以回答用户的问题，提供帮助和建议。请使用中文与用户交流。";
  }
  return prompt.trimLeft();
}

Future<void> setPrompt(String prompt) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  await prefs.setString("description", prompt);
}

Future<List<String>> getWebdav() async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  Set<String> keys = prefs.getKeys();
  if (keys.contains("webdav")) {
    return prefs.getStringList("webdav") ?? ["","",""];
  } else {
    return ["","",""];
  }
}

Future<void> setWebdav(String url, String username, String password) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  await prefs.setStringList("webdav", [url,username,password]);
}

Future<void> setVitsUrl(String url) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  await prefs.setString("vits_url", url);
}

Future<String?> getVitsUrl() async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  String? url = prefs.getString("vits_url");
  if (url == null || url.isEmpty) {
    return "https://indexteam-indextts-2-demo.hf.space/";
  }
  return url;
}

Future<void> setDrawUrl(String url) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  await prefs.setString("draw_url", url);
}

Future<String?> getDrawUrl() async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  String? url = prefs.getString("draw_url");
  if (url == null || url.isEmpty) {
    return "https://r3gm-diffusecraft.hf.space";
  }
  return url;
}

Future<void> setStatusPrompt(String format) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  await prefs.setString("status_prompt", format);
}

Future<String> getStatusPrompt() async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  String? format = prefs.getString("status_prompt");
  if (format == null || format.isEmpty) {
    return "简要描述角色当前的状态，包括好感度、服装、动作、心里话，好感度满分为100分。你可以使用markdown语法绘制表格。";
  }
  return format;
}

Future<void> setStartPrompt(String format) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  await prefs.setString("start_prompt", format);
}

Future<String> getStartPrompt() async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  String? format = prefs.getString("start_prompt");
  if (format == null || format.isEmpty) {
    return "现在开始角色扮演游戏，下面是你的角色设定。";
  }
  return format;
}

Future<void> setEndPrompt(String format) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  await prefs.setString("system_prompt", format);
}

Future<String> getEndPrompt() async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  String? format = prefs.getString("system_prompt");
  if (format == null || format.isEmpty) {
    return "请你扮演{{char}}用一段或多段话回复并推进剧情，可以使用反斜杠来间隔。你可以使用markdown语法，斜体表示状态。";
  }
  return format;
}

Future<void> setResponseRegex(String format) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  await prefs.setString("response_regex", format);
}

Future<String> getResponseRegex() async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  String? format = prefs.getString("response_regex");
  if (format == null || format.isEmpty) {
    return "<think>.*?</think>";
  }
  return format;
}

Future<void> setVitsConfig(VitsConfig config) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  List<String> configList = [
    config.prompt, 
    config.happy?.toString()??'',
    config.angry?.toString()??'',
    config.sad?.toString()??'',
    config.afraid?.toString()??'',
    config.disgusted?.toString()??'',
    config.melancholic?.toString()??'',
    config.surprised?.toString()??'',
    config.calm?.toString()??''
  ];
  await prefs.setStringList("vits_config", configList);
}

Future<VitsConfig> getVitsConfig() async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  List<String> configList = prefs.getStringList("vits_config") ?? ['','0','0','0','0','0','0','0','0'];
  final memConfig = VitsConfig(
    prompt: configList[0],
    happy: double.tryParse(configList[1]) ,
    angry: double.tryParse(configList[2]) ,
    sad: double.tryParse(configList[3]) ,
    afraid: double.tryParse(configList[4]) ,
    disgusted: double.tryParse(configList[5]) ,
    melancholic: double.tryParse(configList[6]) ,
    surprised: double.tryParse(configList[7]) ,
    calm: double.tryParse(configList[8]) ,
  );
  if(memConfig.prompt.isEmpty) {
    memConfig.prompt = "https://static.wikitide.net/bluearchivewiki/c/ca/Mika_Cafe_monolog_1.ogg";
  }
  return memConfig;
}

Future<void> setSdConfig(SdConfig config) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  List<String> configList = [config.prompt, config.negativePrompt, config.model, 
    config.sampler, config.width?.toString()??'', config.height?.toString()??'',
    config.steps?.toString()??'', config.cfg?.toString()??''];
  await prefs.setStringList("sd_config", configList);
}

Future<SdConfig> getSdConfig() async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  List<String> configList = prefs.getStringList("sd_config") ?? ['','','','','','','',''];
  final memConfig = SdConfig(prompt: configList[0], negativePrompt: configList[1], model: configList[2],
    sampler: configList[3], width: int.tryParse(configList[4]), height: int.tryParse(configList[5]),
    steps: int.tryParse(configList[6]), cfg: int.tryParse(configList[7]));
  if(memConfig.prompt.isEmpty) {
    memConfig.prompt = '1girl, VERB, masterpiece, high score, great score, absurdres';
  }
  if(memConfig.negativePrompt.isEmpty) {
    memConfig.negativePrompt = 'lowres, bad anatomy, bad hands, text, error, missing finger, extra digits, fewer digits, cropped, worst quality, low quality, low score, bad score, average score, signature, watermark, username, blurry';
  }
  if(memConfig.model.isEmpty) {
    memConfig.model = 'cagliostrolab/animagine-xl-4.0';
  }
  if(memConfig.sampler.isEmpty) {
    memConfig.sampler = 'Euler a';
  }
  memConfig.width ??= 1024;
  memConfig.height ??= 1600;
  memConfig.steps ??= 28;
  memConfig.cfg ??= 5;
  return memConfig;
}

Future<void> restoreFromJson(jsonString) async {
  if (jsonString.isEmpty) return;

  final prefs = await SharedPreferences.getInstance();
  prefs.clear();
  Map<String, dynamic> allPrefs = jsonDecode(jsonString);

  for (String key in allPrefs.keys) {
    var value = allPrefs[key];
    if (value is String) {
      await prefs.setString(key, value);
    } else if (value is int) {
      await prefs.setInt(key, value);
    } else if (value is double) {
      await prefs.setDouble(key, value);
    } else if (value is bool) {
      await prefs.setBool(key, value);
    } else if (value is List) {
      await prefs.setStringList(key, value.map((item) => item.toString()).toList());
    }
  }
}

Future<void> restoreHistoryFromJson(jsonString) async {
  if (jsonString.isEmpty) return;

  Map<String, dynamic> data = jsonDecode(jsonString);
  // get name and entries fields, and get content in entries as system msg
  String name = data['name'] ?? '未命名故事';
  List<dynamic> entries = data['entries'] ?? [];

  List<Message> messages = [];
  for (var entry in entries) {
    if (entry is Map<String, dynamic> && entry.containsKey('content')) {
      messages.add(Message(message: entry['content'], type: Message.system));
    }
  }

  if (messages.isNotEmpty) {
    String msgJson = msgListToJson(messages);
    await addHistory(msgJson, name);
  }
}

Future<bool> downloadHistorytoJson(String name, List<String> msgs) async {
  List<Map<String, dynamic>> entries = [];
  for (int i = 0; i < msgs.length; i++) {
    entries.add({
      'keys': [],
      'content': msgs[i],
      'extensions': {},
      'enabled': true,
      'insertion_order': i,
      'constant': true, // Always include in the prompt
    });
  }

  Map<String, dynamic> characterBook = {
    'name': name,
    'description': '', // You can add a description if available
    'extensions': {},
    'entries': entries,
  };

  return writeFile(jsonEncode(characterBook));
}

Future<String?> pickFile() async{
  FilePickerResult? result = await FilePicker.platform.pickFiles(type:FileType.custom, allowedExtensions: ['json']);
  if(result != null) {
    debugPrint("File selected: ${result.files.single}");
    String content = utf8.decode(result.files.single.bytes!);
    return content;
  } else {
    debugPrint("No file selected, $result");
    return null;
  }
}

Future<void> loadCharacterCard(context) async {
  // 1. 让用户选择一个 PNG 或 JSON 文件
  FilePickerResult? result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['png','json'],
  );

  if (result != null && result.files.single.bytes != null) {

    String jsonString = '';
    if(result.files.single.extension == 'png'){
      // 2. 获取文件的原始字节 (Uint8List)
      Uint8List imageBytes = result.files.single.bytes!;

      // 3. 使用 'image' 包解码 PNG
      img.Image? image = img.decodePng(imageBytes);

      if (image == null) {
        debugPrint("错误: 无法解码 PNG。");
        return;
      }

      // 4. 关键步骤：从 PNG 元数据中提取 'chara' 键
      // image.textData 是一个 Map<String, String>，它自动读取了所有 tEXt 块
      String? rawData = image.textData?['chara'];

      if (rawData != null) {
        debugPrint("成功找到 'chara' 元数据。");

        try {
          // 5. Base64 解码 (从 String 变为 List<int>)
          List<int> decodedBytes = base64Decode(rawData);

          // 6. UTF-8 解码 (从 List<int> 变为 String)
          jsonString = utf8.decode(decodedBytes);

          debugPrint("解码后的 JSON 字符串: $jsonString");
        } catch (e) {
          snackBarAlert(context,"解码 'chara' 数据时出错: $e");
          return;
        }
      } else {
        snackBarAlert(context,"错误: 未找到 'chara' 元数据。");
        return;
      }
    }
    else{
      jsonString = utf8.decode(result.files.single.bytes!);
    }

    if(jsonString.isEmpty){
      snackBarAlert(context,"错误: JSON 字符串为空。");
      return;
    }
    // 7. 解析 JSON 并恢复 SharedPreferences
    Map<String, dynamic> allPrefs = jsonDecode(jsonString);

    final prefs = await SharedPreferences.getInstance();
    if (allPrefs.containsKey("data")) {
      Map<String, dynamic> data = allPrefs["data"];
      for (String key in data.keys) {
        if (key == "name" || key == "avatar" || key == "first_mes" || key == "description") {
          prefs.setString(key, data[key].replaceAll('<user>', '{{user}}'));
        }
        if (key == "character_book") {
            final characterBook = data['character_book'];
            if (characterBook != null && characterBook is Map<String, dynamic>) {
            final bool? confirmImport = await showDialog<bool>(
              context: context,
              builder: (BuildContext context) {
              return AlertDialog(
                title: const Text('导入角色书'),
                content: const Text('检测到角色卡中包含角色书，是否将其作为故事导入？'),
                actions: <Widget>[
                TextButton(
                  child: const Text('取消'),
                  onPressed: () {
                  Navigator.of(context).pop(false);
                  },
                ),
                TextButton(
                  child: const Text('导入'),
                  onPressed: () {
                  Navigator.of(context).pop(true);
                  },
                ),
                ],
              );
              },
            );

            if (confirmImport == true) {
              final String bookJsonString = jsonEncode(characterBook);
              await restoreHistoryFromJson(bookJsonString);
              snackBarAlert(context, '角色书已作为故事导入。');
            }
          }
        }
      }
    }

    // 8. 如果是 PNG 文件，则转为 Base64 存储头像
    if(result.files.single.extension == 'png'){
      String base64Image = base64Encode(result.files.single.bytes!);
      await prefs.setString("avatar", "data:image/png;base64,$base64Image");
    }

  } else {
    // 用户取消了选择
    snackBarAlert(context, "未选择文件。");
  }
}

Future<void> downloadCharacterCard(context) async {
  try {
    // 1. 收集角色数据
    final prefs = await SharedPreferences.getInstance();
    final name = await getStudentName();
    final description = await getPrompt();
    final firstMes = await getOriginalMsg();

    final characterData = {
      "spec": "chara_card_v2",
      "spec_version": "2.0",
      "data": {
        "name": name,
        "description": description,
        "first_mes": firstMes,
      }
    };

    // 2. 将角色数据转换为 Base64 编码的 JSON 字符串
    final jsonString = jsonEncode(characterData);
    final base64String = base64Encode(utf8.encode(jsonString));

    // 3. 获取并解码头像图片
    String avatarUri = await getAvatar();
    Uint8List imageBytes;

    if (avatarUri.startsWith('data:image')) {
      imageBytes = base64Decode(avatarUri.split(',')[1]);
    } else if (avatarUri.startsWith('http://') || avatarUri.startsWith('https://')) {
      final uri = Uri.parse(avatarUri);
      if (kIsWeb) {
        // Web 平台使用 http 包
        final response = await http.get(uri);
        imageBytes = response.bodyBytes;
      } else {
        // 其他平台使用 dart:io 的 HttpClient
        final request = await HttpClient().getUrl(uri);
        final response = await request.close();
        imageBytes = await consolidateHttpClientResponseBytes(response);
      }
    } else {
      final byteData = await rootBundle.load(avatarUri);
      imageBytes = byteData.buffer.asUint8List();
    }

    img.Image? image = img.decodeImage(imageBytes);
    if (image == null) {
      snackBarAlert(context, "无法解码头像图片。");
      return;
    }

    // 4. 将 Base64 字符串作为 'chara' 元数据添加到图片中
    image.textData = {'chara': base64String};

    // 5. 将图片编码回 PNG 格式
    final Uint8List outputBytes = Uint8List.fromList(img.encodePng(image));

    // 6. 提示用户保存文件 (区分 Web 和其他平台)
    await writePngFile(outputBytes);
  } catch (e) {
    debugPrint("下载角色卡时出错: $e");
    snackBarAlert(context, "下载角色卡时出错: $e");
  }
}