import 'dart:convert';
import 'package:eventflux/eventflux.dart';
import 'utils.dart' show Config;

String removeTailSlash(String input) {
  return input.trimRight().endsWith('/')
      ? input.trimRight().substring(0, input.trimRight().length - 1)
      : input.trimRight();
}

/// 流式 SSE 回调包装
/// 确保 onDone/onError 在各种结束条件下都能触发
void _listenStream(Stream<EventFluxData>? stream,
    Function onEvent, Function onDone, Function onErr) {
  bool finished = false;

  void finish(Function cb) {
    if (finished) return;
    finished = true;
    cb();
  }

  stream?.listen((data) {
    try {
      onEvent(json.decode(data.data)["choices"][0]["delta"]["content"]);
    } catch (e) {
      // DONE 标记或任何解析异常都视为流结束
      finish(onDone);
    }
  }, onDone: () {
    finish(onDone);
  }, onError: (e) {
    finish(() => onErr('Stream error: $e'));
  });
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
        _listenStream(response?.stream, onEevent, onDone, onErr);
      },
      onError: (oops) => onErr(oops.message));
}
