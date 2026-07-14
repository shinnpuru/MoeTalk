import 'dart:convert';
import 'package:eventflux/eventflux.dart';
import 'utils.dart' show Config;

String removeTailSlash(String input) {
  return input.trimRight().endsWith('/')
      ? input.trimRight().substring(0, input.trimRight().length - 1)
      : input.trimRight();
}

/// 独立实例版本的 completion，使用 EventFlux.spawn() 避免单例冲突
/// 适用于需要和主聊天流并行的请求（如角色卡生成、AI绘图等）
Future<void> completionIsolated(Config config, List<List<String>> message,
    Function onEvent, Function onDone, Function onErr) async {

  Map<String, dynamic> data = {
    'model': config.model,
    'messages':
        message.asMap().map((index, e) {
          if (e[0]=="system" && config.model.contains("claude")) {
            return MapEntry(index, {'role': 'user', 'content': "system instruction:\n${e[1]}"});
          }
          return MapEntry(index, {'role': e[0], 'content': e[1]});
        }).values.toList(),
    'stream': true,
    if (config.temperature != null && double.tryParse(config.temperature!) != null) 
      'temperature': double.parse(config.temperature!),
    if (config.frequencyPenalty != null && double.tryParse(config.frequencyPenalty!) != null)
      'frequency_penalty': double.parse(config.frequencyPenalty!),
    if (config.presencePenalty != null && double.tryParse(config.presencePenalty!) != null)
      'presence_penalty': double.parse(config.presencePenalty!),
    if (config.maxTokens != null && int.tryParse(config.maxTokens!) != null)
      'max_tokens': int.parse(config.maxTokens!),
  };

  final flux = EventFlux.spawn();
  flux.connect(EventFluxConnectionType.post,
      "${removeTailSlash(config.baseUrl)}/chat/completions",
      header: {
        'Authorization': 'Bearer ${config.apiKey}',
        'Content-Type': 'application/json',
      },
      body: data,
      onSuccessCallback: (EventFluxResponse? response) {
        response?.stream?.listen((data) {
          try {
            onEvent(json.decode(data.data)["choices"][0]["delta"]["content"]);
          } catch (e) {
            if (data.data.contains("DONE")) {
              onDone();
            } else if(e is FormatException) {
              onErr("Unexpected response: \n${data.data}");
            } else {
              // 其他未知异常也视为可能结束
              onDone();
            }
          }
        }, onDone: () {
          // 流正常关闭（如某些 API 不发送 [DONE] 直接断连）
          onDone();
        }, onError: (e) {
          onErr('Stream error: $e');
        });
      },
      onError: (oops) => onErr(oops.message));
}

Future<void> completion(Config config, List<List<String>> message,
    Function onEevent, Function onDone, Function onErr) async {

  Map<String, dynamic> data = {
    'model': config.model,
    'messages':
        message.asMap().map((index, e) {
          if (e[0]=="system" && config.model.contains("claude")) {
            return MapEntry(index, {'role': 'user', 'content': "system instruction:\n${e[1]}"});
          }
          return MapEntry(index, {'role': e[0], 'content': e[1]});
        }).values.toList(),
    'stream': true,
    if (config.temperature != null && double.tryParse(config.temperature!) != null) 
      'temperature': double.parse(config.temperature!),
    if (config.frequencyPenalty != null && double.tryParse(config.frequencyPenalty!) != null)
      'frequency_penalty': double.parse(config.frequencyPenalty!),
    if (config.presencePenalty != null && double.tryParse(config.presencePenalty!) != null)
      'presence_penalty': double.parse(config.presencePenalty!),
    if (config.maxTokens != null && int.tryParse(config.maxTokens!) != null)
      'max_tokens': int.parse(config.maxTokens!),
  };
  // print(data);
  EventFlux.instance.connect(EventFluxConnectionType.post,
      "${removeTailSlash(config.baseUrl)}/chat/completions",
      header: {
        'Authorization': 'Bearer ${config.apiKey}',
        'Content-Type': 'application/json',
      },
      body: data,
      onSuccessCallback: (EventFluxResponse? response) {
        response?.stream?.listen((data) {
          try {
            onEevent(json.decode(data.data)["choices"][0]["delta"]["content"]);
          } catch (e) {
            if (data.data.contains("DONE")) {
              onDone();
            } else if(e is FormatException) {
              onErr("Unexpected response: \n${data.data}");
            } else {
              // 其他未知异常也视为可能结束
              onDone();
            }
          }
        }, onDone: () {
          // 流正常关闭（如某些 API 不发送 [DONE] 直接断连）
          onDone();
        }, onError: (e) {
          onErr('Stream error: $e');
        });
      },
      onError: (oops) => onErr(oops.message));
}
