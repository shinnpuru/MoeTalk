import 'utils.dart' show Config, ThinkingApi, ThinkingMode;

/// All completions (including connection tests) use this same wire format.
/// Automatic mode without an effort sends no override to older/non-reasoning
/// models. Proxies can explicitly select the upstream provider's format.
Map<String, dynamic> thinkingParameters(Config config) {
  final mode = config.thinkingMode;
  final effort = config.thinkingEffort;
  if (mode == ThinkingMode.automatic && effort == null) return {};

  var api = config.thinkingApi;
  if (api == ThinkingApi.automatic) {
    final host = Uri.tryParse(config.baseUrl.trim())?.host.toLowerCase();
    api = host == 'api.deepseek.com'
        ? ThinkingApi.deepseek
        : host == 'openrouter.ai'
            ? ThinkingApi.openrouter
            : ThinkingApi.openai;
  }
  final enabled = mode != ThinkingMode.disabled;
  switch (api) {
    case ThinkingApi.deepseek:
      return {
        'thinking': {'type': enabled ? 'enabled' : 'disabled'},
        if (enabled && effort != null) 'reasoning_effort': effort,
      };
    case ThinkingApi.openrouter:
      return {
        'reasoning': {
          'enabled': enabled,
          if (enabled && effort != null) 'effort': effort,
        },
      };
    case ThinkingApi.llamaCpp:
      return {
        'chat_template_kwargs': {'enable_thinking': enabled},
        if (!enabled || effort != null)
          'reasoning_effort': enabled ? effort : 'none',
      };
    case ThinkingApi.openai:
    case ThinkingApi.automatic:
      // Gemini's OpenAI-compatible endpoint also accepts reasoning_effort.
      return {'reasoning_effort': enabled ? effort ?? 'medium' : 'none'};
  }
}
