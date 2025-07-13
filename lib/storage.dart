import 'dart:convert';
import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'utils.dart';

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

Future<void> addStudent(String name, String avatar, String first_mes, String description) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  String timeStamp = DateTime.now().millisecondsSinceEpoch.toString();
  await prefs.setStringList("student_${timeStamp}_$name", [name,avatar,first_mes,description,timeStamp]);
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
     return "assets/head.webp";
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
  
  Map<String, dynamic> allPrefs = {"data":{}};
  for (String key in keys) {
    // "name" "avatar" "first_mes" "description" save to data
    if (key == "name" || key == "avatar" || key == "first_mes" || key == "description") {
      allPrefs["data"][key] = prefs.get(key);
    } else {
      allPrefs[key] = prefs.get(key);
    }
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
    return "用户";
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
    return "https://shinnpuru-vits-models.hf.space/";
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

Future<void> setStartPrompt(String format) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  await prefs.setString("start_prompt", format);
}

Future<String> getStartPrompt() async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  String? format = prefs.getString("start_prompt");
  if (format == null || format.isEmpty) {
    return "现在开始角色扮演。";
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
    String? name = await getStudentName(isDefault: true);
    return "你可以开始扮演$name。";
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
    return "<think>.*?<\/think>";
  }
  return format;
}

Future<void> setVitsConfig(VitsConfig config) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  List<String> configList = [config.model, config.language, 
    config.noiseScale?.toString() ?? '', config.noiseScaleW?.toString() ?? '', 
    config.lengthScale?.toString() ?? ''];
  await prefs.setStringList("vits_config", configList);
}

Future<VitsConfig> getVitsConfig() async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  List<String> configList = prefs.getStringList("vits_config") ?? ['','','','',''];
  final memConfig = VitsConfig(model: configList[0], language: configList[1],
    noiseScale: double.tryParse(configList[2]), noiseScaleW: double.tryParse(configList[3]),
    lengthScale: double.tryParse(configList[4]));
  if(memConfig.model.isEmpty) {
    memConfig.model = 'tts-Misono%20Mika';
  }
  if(memConfig.language.isEmpty) {
    memConfig.language = 'Chinese';
  }
  memConfig.noiseScale ??= 0.6;
  memConfig.noiseScaleW ??= 0.7;
  memConfig.lengthScale ??= 1.2;
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

  if (allPrefs.containsKey("data")) {
    Map<String, dynamic> data = allPrefs["data"];
    for (String key in data.keys) {
      if (key == "name" || key == "avatar" || key == "first_mes" || key == "description") {
        prefs.setString(key, data[key]);
      }
    }
  }

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
