import 'dart:async';
import 'dart:convert';
import 'package:eventflux/eventflux.dart';
import 'utils.dart' show Config;
import 'model_thinking.dart';

String removeTailSlash(String input) {
  return input.trimRight().endsWith('/')
      ? input.trimRight().substring(0, input.trimRight().length - 1)
      : input.trimRight();
}

/// Accept existing Gemini presets that predate the OpenAI compatibility path.
Uri completionEndpoint(String baseUrl) {
  var base = baseUrl.trim().replaceFirst(RegExp(r'/+$'), '');
  final uri = Uri.parse(base);
  if (uri.host == 'generativelanguage.googleapis.com' &&
      RegExp(r'^/v1(?:beta)?$').hasMatch(uri.path)) {
    base = '$base/openai';
  }
  return Uri.parse('$base/chat/completions');
}

Map<String, dynamic> completionPayload(
    Config config, List<List<String>> message) {
  final endpoint = completionEndpoint(config.baseUrl);
  final openAiReasoning = endpoint.host == 'api.openai.com' &&
      RegExp(r'^(o[134](?:-|$)|gpt-5(?:[.-]|$))').hasMatch(config.model);
  return {
    'model': config.model,
    'messages': message
        .asMap()
        .map((index, e) {
          if (e[0] == "system" && config.model.contains("claude")) {
            return MapEntry(index,
                {'role': 'user', 'content': "system instruction:\n${e[1]}"});
          }
          return MapEntry(index, {'role': e[0], 'content': e[1]});
        })
        .values
        .toList(),
    'stream': true,
    ...thinkingParameters(config),
    if (!openAiReasoning &&
        config.temperature != null &&
        double.tryParse(config.temperature!) != null)
      'temperature': double.parse(config.temperature!),
    if (!openAiReasoning &&
        config.frequencyPenalty != null &&
        double.tryParse(config.frequencyPenalty!) != null)
      'frequency_penalty': double.parse(config.frequencyPenalty!),
    if (!openAiReasoning &&
        config.presencePenalty != null &&
        double.tryParse(config.presencePenalty!) != null)
      'presence_penalty': double.parse(config.presencePenalty!),
    if (config.maxTokens != null && int.tryParse(config.maxTokens!) != null)
      (openAiReasoning ? 'max_completion_tokens' : 'max_tokens'):
          int.parse(config.maxTokens!),
  };
}

Future<void> completion(Config config, List<List<String>> message,
    Function onEevent, Function onDone, Function onErr,
    {Duration? timeout}) async {
  final endpoint = completionEndpoint(config.baseUrl);
  final data = completionPayload(config, message);
  // EventFlux.instance owns only one client, controller and subscription. Using
  // it for overlapping chat, inspire and draw requests makes those streams
  // overwrite each other's state. Give every completion its own SSE client.
  final eventFlux = EventFlux.spawn();
  final terminal = Completer<void>();
  Timer? timeoutTimer;
  bool finished = false;
  void safeDone() {
    if (!finished) {
      finished = true;
      timeoutTimer?.cancel();
      try {
        onDone();
      } finally {
        unawaited(eventFlux.disconnect());
        if (!terminal.isCompleted) terminal.complete();
      }
    }
  }

  void safeErr(dynamic err) {
    if (!finished) {
      finished = true;
      timeoutTimer?.cancel();
      try {
        onErr(err);
      } finally {
        unawaited(eventFlux.disconnect());
        if (!terminal.isCompleted) terminal.complete();
      }
    }
  }

  if (timeout != null) {
    timeoutTimer = Timer(
        timeout,
        () => safeErr(TimeoutException(
            'The language model did not respond in time', timeout)));
  }

  try {
    eventFlux.connect(EventFluxConnectionType.post, endpoint.toString(),
        header: {
          'Authorization': 'Bearer ${config.apiKey}',
          'Content-Type': 'application/json',
        },
        body: data,
        onSuccessCallback: (EventFluxResponse? response) {
          final stream = response?.stream;
          if (stream == null) {
            safeErr('The server returned no response stream');
            return;
          }
          stream.listen((data) {
            if (finished) return;
            try {
              final payload = json.decode(data.data);
              final error = payload['error'];
              if (error != null) {
                safeErr(error is Map ? error['message'] ?? error : error);
                return;
              }
              final content = payload['choices'][0]['delta']['content'];
              if (content != null) {
                onEevent(content);
              }
            } catch (e) {
              if (data.data.contains("DONE")) {
                safeDone();
              } else if (e is FormatException) {
                safeErr("Unexpected response: \n${data.data}");
              }
            }
          }, onDone: () {
            safeDone();
          }, onError: (e) {
            safeErr(e.toString());
          });
        },
        onError: (oops) => safeErr(oops.message));
  } catch (error) {
    safeErr(error);
  }

  await terminal.future;
}

Future<String> collectCompletion(Config config, List<List<String>> messages,
    {Duration? timeout}) async {
  final result = StringBuffer();
  Object? requestError;

  await completion(
    config,
    messages,
    (String chunk) => result.write(chunk),
    () {},
    (dynamic error) => requestError = error,
    timeout: timeout,
  );

  if (requestError != null) throw requestError!;
  return result.toString();
}

/// Check the same streaming completion endpoint and parameters used by chat.
Future<void> testModelConnection(Config config,
    {Duration timeout = const Duration(seconds: 120)}) async {
  final response = await collectCompletion(
    config,
    const [
      ['user', 'Reply with OK.'],
    ],
    timeout: timeout,
  );
  if (response.trim().isEmpty) {
    throw const FormatException('The language model returned no reply');
  }
}
