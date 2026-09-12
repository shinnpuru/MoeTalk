import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// Error raised by the stable-diffusion.cpp (`sd-server`) backend.
class SdCppException implements Exception {
  final int? statusCode;
  final String message;

  const SdCppException(this.message, {this.statusCode});

  @override
  String toString() => statusCode == null
      ? 'sd.cpp: $message'
      : 'sd.cpp HTTP $statusCode: $message';
}

/// Raised when the user (or the app) gives up on a running job.
class SdCppCancelledException extends SdCppException {
  const SdCppCancelledException([super.message = 'generation cancelled']);
}

/// A LoRA known to the server (`--lora-model-dir`).
class SdCppLora {
  final String name;
  final String path;

  const SdCppLora({required this.name, required this.path});

  /// File name without its extension, e.g. `myLora` for `myLora.safetensors`.
  String get stem {
    final fileName = path.split(RegExp(r'[\\/]')).last;
    final dot = fileName.lastIndexOf('.');
    return dot > 0 ? fileName.substring(0, dot) : fileName;
  }

  factory SdCppLora.fromJson(Map<dynamic, dynamic> json) => SdCppLora(
        name: json['name']?.toString() ?? '',
        path: json['path']?.toString() ?? '',
      );
}

/// Everything `GET /sdcpp/v1/capabilities` reports about the running server.
class SdCppCapabilities {
  final String modelStem;
  final String modelName;
  final List<String> samplers;
  final List<String> schedulers;
  final List<SdCppLora> loras;
  final List<String> supportedModes;
  final List<String> outputFormats;
  final int? minWidth;
  final int? maxWidth;
  final int? minHeight;
  final int? maxHeight;

  const SdCppCapabilities({
    this.modelStem = '',
    this.modelName = '',
    this.samplers = const [],
    this.schedulers = const [],
    this.loras = const [],
    this.supportedModes = const [],
    this.outputFormats = const [],
    this.minWidth,
    this.maxWidth,
    this.minHeight,
    this.maxHeight,
  });

  bool get supportsImageGeneration =>
      supportedModes.isEmpty || supportedModes.contains('img_gen');

  String get displayModel => modelStem.isNotEmpty
      ? modelStem
      : (modelName.isNotEmpty ? modelName : 'unknown');

  factory SdCppCapabilities.fromJson(Map<String, dynamic> json) {
    final model = json['model'];
    final limits = json['limits'];
    final loras = <SdCppLora>[];
    final rawLoras = json['loras'];
    if (rawLoras is List) {
      for (final entry in rawLoras) {
        if (entry is Map) loras.add(SdCppLora.fromJson(entry));
      }
    }
    return SdCppCapabilities(
      modelStem: model is Map ? (model['stem']?.toString() ?? '') : '',
      modelName: model is Map ? (model['name']?.toString() ?? '') : '',
      samplers: _stringList(json['samplers']),
      schedulers: _stringList(json['schedulers']),
      loras: loras,
      supportedModes: _stringList(json['supported_modes']),
      outputFormats: _stringList(json['output_formats']),
      minWidth: limits is Map ? _intOrNull(limits['min_width']) : null,
      maxWidth: limits is Map ? _intOrNull(limits['max_width']) : null,
      minHeight: limits is Map ? _intOrNull(limits['min_height']) : null,
      maxHeight: limits is Map ? _intOrNull(limits['max_height']) : null,
    );
  }
}

/// One LoRA override sent with a generation request.
class SdCppLoraRef {
  final String path;
  final double multiplier;

  const SdCppLoraRef({required this.path, this.multiplier = 1.0});

  Map<String, dynamic> toJson() => {
        'path': path,
        'multiplier': multiplier,
        'is_high_noise': false,
      };
}

/// A `POST /sdcpp/v1/img_gen` payload.
class SdCppImageRequest {
  final String prompt;
  final String negativePrompt;
  final int width;
  final int height;
  final int steps;
  final double cfgScale;
  final int? seed;
  final int? clipSkip;
  final String? sampleMethod;
  final String? scheduler;
  final List<SdCppLoraRef> loras;
  final String outputFormat;

  const SdCppImageRequest({
    required this.prompt,
    this.negativePrompt = '',
    this.width = 1024,
    this.height = 1024,
    this.steps = 20,
    this.cfgScale = 7.0,
    this.seed,
    this.clipSkip,
    this.sampleMethod,
    this.scheduler,
    this.loras = const [],
    this.outputFormat = 'png',
  });

  Map<String, dynamic> toJson() => {
        'prompt': prompt,
        'negative_prompt': negativePrompt,
        'width': width,
        'height': height,
        'batch_count': 1,
        'output_format': outputFormat,
        if (seed != null) 'seed': seed,
        if (clipSkip != null && clipSkip! > 0) 'clip_skip': clipSkip,
        'sample_params': {
          'sample_steps': steps,
          'guidance': {'txt_cfg': cfgScale},
          if (sampleMethod != null) 'sample_method': sampleMethod,
          if (scheduler != null) 'scheduler': scheduler,
        },
        if (loras.isNotEmpty)
          'lora': loras.map((lora) => lora.toJson()).toList(growable: false),
      };
}

/// A generated image: base64 payload plus its container format.
class SdCppJobImage {
  final String base64;
  final String format;

  const SdCppJobImage({required this.base64, this.format = 'png'});

  Uint8List get bytes => base64Decode(base64);

  /// File extension matching [format].
  String get extension {
    switch (format.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
        return 'jpg';
      case 'webp':
        return 'webp';
      default:
        return 'png';
    }
  }
}

/// A job snapshot from `GET /sdcpp/v1/jobs/{id}`.
class SdCppJob {
  final String id;
  final String status;
  final int? queuePosition;
  final List<SdCppJobImage> images;
  final String? outputFormat;
  final String? error;

  const SdCppJob({
    required this.id,
    required this.status,
    this.queuePosition,
    this.images = const [],
    this.outputFormat,
    this.error,
  });

  bool get isCompleted => status == 'completed';
  bool get isFailed => status == 'failed';
  bool get isCancelled => status == 'cancelled';
  bool get isTerminal => isCompleted || isFailed || isCancelled;

  factory SdCppJob.fromJson(Map<String, dynamic> json) {
    final images = <SdCppJobImage>[];
    String? outputFormat;
    final result = json['result'];
    if (result is Map) {
      outputFormat = result['output_format']?.toString();
      final rawImages = result['images'];
      if (rawImages is List) {
        for (final entry in rawImages) {
          if (entry is! Map) continue;
          final payload = entry['b64_json']?.toString();
          if (payload == null || payload.isEmpty) continue;
          images.add(SdCppJobImage(
            base64: payload,
            format: entry['output_format']?.toString() ??
                outputFormat ??
                'png',
          ));
        }
      }
    }
    return SdCppJob(
      id: json['id']?.toString() ?? '',
      status: json['status']?.toString() ?? 'unknown',
      queuePosition: _intOrNull(json['queue_position']),
      images: images,
      outputFormat: outputFormat,
      error: _errorMessage(json['error']),
    );
  }
}

/// Thin HTTP client for a stable-diffusion.cpp server (`sd-server`).
///
/// The server is expected to be started separately, for example:
/// `sd-server.exe -m model.safetensors --listen-port 1234`.
class SdCppClient {
  static const defaultBaseUrl = 'http://127.0.0.1:1234';

  final String baseUrl;
  final http.Client? httpClient;
  final Duration defaultTimeout;
  final Duration pollInterval;

  const SdCppClient({
    required this.baseUrl,
    this.httpClient,
    this.defaultTimeout = const Duration(seconds: 60),
    this.pollInterval = const Duration(milliseconds: 800),
  });

  /// Reads the server capabilities, which also validates the connection.
  Future<SdCppCapabilities> fetchCapabilities() async {
    final response = await _get('/sdcpp/v1/capabilities');
    final json = _decodeObject(response);
    if (json == null) {
      throw SdCppException(
        'capabilities response is not a JSON object',
        statusCode: response.statusCode,
      );
    }
    return SdCppCapabilities.fromJson(json);
  }

  /// Queues an image generation job and returns its id.
  Future<String> submitImage(SdCppImageRequest request) async {
    final response = await _postJson('/sdcpp/v1/img_gen', request.toJson());
    final json = _decodeObject(response);
    final id = json?['id']?.toString() ?? '';
    if (id.isEmpty) {
      throw SdCppException(
        'image generation response did not contain a job id',
        statusCode: response.statusCode,
      );
    }
    return id;
  }

  Future<SdCppJob> fetchJob(String jobId) async {
    final response = await _get('/sdcpp/v1/jobs/$jobId');
    return _jobFromResponse(response);
  }

  Future<void> cancelJob(String jobId) async {
    final response = await _postJson('/sdcpp/v1/jobs/$jobId/cancel', const {});
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _responseException(response);
    }
  }

  /// Polls [jobId] until it finishes, fails, is cancelled or [maxWait] elapses.
  ///
  /// [isCancelled] is polled between requests; when it turns true the job is
  /// cancelled on the server and [SdCppCancelledException] is thrown.
  Future<SdCppJob> waitForJob(
    String jobId, {
    void Function(SdCppJob job)? onUpdate,
    bool Function()? isCancelled,
    Duration? pollInterval,
    Duration maxWait = const Duration(minutes: 30),
  }) async {
    final interval = pollInterval ?? this.pollInterval;
    final deadline = DateTime.now().add(maxWait);
    var cancelRequested = false;

    while (true) {
      if (isCancelled?.call() ?? false) {
        if (!cancelRequested) {
          cancelRequested = true;
          try {
            await cancelJob(jobId);
          } catch (_) {
            // The job may already be gone; the caller only cares about stopping.
          }
        }
        throw const SdCppCancelledException();
      }

      final job = await fetchJob(jobId);
      onUpdate?.call(job);
      if (job.isCompleted) return job;
      if (job.isFailed) {
        throw SdCppException(job.error ?? 'generation failed');
      }
      if (job.isCancelled) {
        throw const SdCppCancelledException();
      }
      if (DateTime.now().isAfter(deadline)) {
        try {
          await cancelJob(jobId);
        } catch (_) {
          // Best effort: the job is abandoned either way.
        }
        throw SdCppException('generation timed out after ${maxWait.inMinutes}m');
      }
      await Future<void>.delayed(interval);
    }
  }

  /// Builds an absolute endpoint URL, tolerating a missing scheme or a
  /// trailing slash in [baseUrl].
  Uri endpoint(String path) {
    final normalized = baseUrl.trim().replaceFirst(RegExp(r'/+$'), '');
    if (normalized.isEmpty) {
      throw const SdCppException('sd.cpp server URL is not configured');
    }
    final hasScheme =
        RegExp(r'^[a-zA-Z][a-zA-Z0-9+.\-]*://').hasMatch(normalized);
    final uri = Uri.tryParse('${hasScheme ? normalized : 'http://$normalized'}$path');
    if (uri == null || uri.host.isEmpty) {
      throw SdCppException('invalid sd.cpp server URL: $baseUrl');
    }
    return uri;
  }

  Future<http.Response> _get(String path) {
    final client = httpClient;
    final uri = endpoint(path);
    final request = client == null
        ? http.get(uri, headers: const {'Accept': 'application/json'})
        : client.get(uri, headers: const {'Accept': 'application/json'});
    return request.timeout(defaultTimeout);
  }

  Future<http.Response> _postJson(String path, Map<String, dynamic> body) {
    const headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    final encoded = jsonEncode(body);
    final uri = endpoint(path);
    final client = httpClient;
    final request = client == null
        ? http.post(uri, headers: headers, body: encoded)
        : client.post(uri, headers: headers, body: encoded);
    return request.timeout(defaultTimeout);
  }

  SdCppJob _jobFromResponse(http.Response response) {
    final json = _decodeObject(response);
    if (json == null) {
      throw SdCppException(
        'job response is not a JSON object',
        statusCode: response.statusCode,
      );
    }
    return SdCppJob.fromJson(json);
  }

  Map<String, dynamic>? _decodeObject(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _responseException(response);
    }
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      return decoded is Map<String, dynamic> ? decoded : null;
    } on FormatException catch (error) {
      throw SdCppException(
        'invalid JSON response: ${error.message}',
        statusCode: response.statusCode,
      );
    }
  }

  static SdCppException _responseException(http.Response response) {
    var message = response.reasonPhrase ?? 'request failed';
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      final error = decoded is Map ? decoded['error'] : null;
      final parsed = _errorMessage(error);
      if (parsed != null && parsed.isNotEmpty) {
        message = parsed;
      }
    } catch (_) {
      final body = utf8.decode(response.bodyBytes, allowMalformed: true).trim();
      if (body.isNotEmpty) message = body;
    }
    return SdCppException(message, statusCode: response.statusCode);
  }
}

String? _errorMessage(Object? error) {
  if (error == null) return null;
  if (error is Map) {
    final message = error['message'];
    if (message != null) return message.toString();
    return error.isEmpty ? null : error.toString();
  }
  final text = error.toString();
  return text.isEmpty ? null : text;
}

List<String> _stringList(Object? value) {
  if (value is! List) return const [];
  return value
      .map((entry) => entry?.toString() ?? '')
      .where((entry) => entry.isNotEmpty)
      .toList(growable: false);
}

int? _intOrNull(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

/// The sampler/scheduler pair resolved from the app's sampler text field.
class SdCppSamplerSelection {
  final String? sampleMethod;
  final String? scheduler;

  /// Set when the requested sampler has no sd.cpp equivalent.
  final String? unsupportedSampler;

  /// Set when a scheduler was recognised but the server does not offer it.
  final String? ignoredScheduler;

  const SdCppSamplerSelection({
    this.sampleMethod,
    this.scheduler,
    this.unsupportedSampler,
    this.ignoredScheduler,
  });
}

/// Maps A1111/Civitai sampler names (what the app stores) onto the
/// `sample_method` and `scheduler` values sd.cpp understands.
SdCppSamplerSelection resolveSdCppSampler(
  String raw, {
  Iterable<String> availableMethods = const [],
  Iterable<String> availableSchedulers = const [],
}) {
  final text = raw.trim();
  if (text.isEmpty) return const SdCppSamplerSelection();

  final whole = _normalizeSamplerToken(text);
  String? method;
  String? scheduler;
  String? unsupported;

  if (_samplerAliases.containsKey(whole)) {
    final alias = _samplerAliases[whole]!;
    if (alias.isNotEmpty) method = alias;
  } else {
    final methodParts = <String>[];
    for (final token in text.split(RegExp(r'[\s,;/|]+'))) {
      if (token.isEmpty) continue;
      final normalized = _normalizeSamplerToken(token);
      if (methodParts.isNotEmpty && _schedulerAliases.containsKey(normalized)) {
        scheduler ??= _schedulerAliases[normalized];
        continue;
      }
      methodParts.add(normalized);
    }
    final candidate = methodParts.join();
    if (_samplerAliases.containsKey(candidate)) {
      final alias = _samplerAliases[candidate]!;
      if (alias.isNotEmpty) method = alias;
    } else if (candidate.isEmpty) {
      // Nothing usable in the field; fall through to the server default.
    } else if (_schedulerAliases.containsKey(candidate) &&
        scheduler == null) {
      scheduler = _schedulerAliases[candidate];
    } else {
      unsupported = text;
    }
  }

  final methodNames = _normalizedSet(availableMethods);
  if (method != null &&
      methodNames.isNotEmpty &&
      !methodNames.contains(_normalizeSamplerToken(method))) {
    unsupported = text;
    method = null;
  }

  final schedulerNames = _normalizedSet(availableSchedulers);
  String? ignoredScheduler;
  if (scheduler != null &&
      schedulerNames.isNotEmpty &&
      !schedulerNames.contains(_normalizeSamplerToken(scheduler))) {
    ignoredScheduler = scheduler;
    scheduler = null;
  }

  return SdCppSamplerSelection(
    sampleMethod: method,
    scheduler: scheduler,
    unsupportedSampler: unsupported,
    ignoredScheduler: ignoredScheduler,
  );
}

/// Resolves the app's LoRA text into entries the sd.cpp server accepts.
///
/// The app stores either a single name or `<name:weight>` pairs; sd.cpp needs
/// the path of a file inside `--lora-model-dir`, so names are matched against
/// the server's LoRA list. Unresolvable entries are reported through [onSkip]
/// and dropped, because the server rejects unknown paths outright.
List<SdCppLoraRef> resolveSdCppLoras(
  String raw, {
  Iterable<SdCppLora> availableLoras = const [],
  void Function(String skipped)? onSkip,
  void Function(SdCppLoraRef lora, String name)? onResolved,
}) {
  final text = raw.trim();
  if (text.isEmpty) return const [];

  final parsed = <MapEntry<String, double>>[];
  // LoRA names may themselves contain colons (Civitai URNs), so the weight is
  // taken from the last colon of each `<...>` group.
  for (final match in RegExp(r'<([^<>]+)>').allMatches(text)) {
    final content = match.group(1)!.trim();
    if (content.isEmpty) continue;
    final separator = content.lastIndexOf(':');
    var name = content;
    var weight = 1.0;
    if (separator > 0) {
      final parsedWeight =
          double.tryParse(content.substring(separator + 1).trim());
      if (parsedWeight != null) {
        name = content.substring(0, separator).trim();
        weight = parsedWeight;
      }
    }
    if (name.isNotEmpty) parsed.add(MapEntry(name, weight));
  }
  if (parsed.isEmpty) {
    for (final part in text.split(',')) {
      final name = part.trim();
      if (name.isNotEmpty) parsed.add(MapEntry(name, 1.0));
    }
  }

  final loras = <SdCppLoraRef>[];
  for (final entry in parsed) {
    final name = entry.key;
    final match = _matchLora(name, availableLoras);
    if (match == null) {
      onSkip?.call(name);
      continue;
    }
    final resolved = SdCppLoraRef(path: match.path, multiplier: entry.value);
    loras.add(resolved);
    onResolved?.call(resolved, name);
  }
  return loras;
}

SdCppLora? _matchLora(String name, Iterable<SdCppLora> loras) {
  final normalized = name.toLowerCase().replaceAll('\\', '/');
  final fileName = normalized.split('/').last;
  for (final lora in loras) {
    if (lora.path.toLowerCase() == normalized) return lora;
    if (lora.name.toLowerCase() == normalized) return lora;
    if (lora.stem.toLowerCase() == normalized) return lora;
    if (lora.path.toLowerCase().replaceAll('\\', '/').split('/').last ==
        fileName) {
      return lora;
    }
  }
  return null;
}

Set<String> _normalizedSet(Iterable<String> values) =>
    values.map(_normalizeSamplerToken).toSet();

/// Lowercases and strips separators so `DPM++ 2M Karras`, `dpm++2m_karras` and
/// `DPM++2MKarras` collapse to the same key.
String _normalizeSamplerToken(String token) =>
    token.toLowerCase().replaceAll(RegExp(r'[^a-z0-9+]'), '');

/// Normalised sampler alias -> sd.cpp `sample_method` ('' means "server
/// default"; names without an sd.cpp equivalent are not listed at all).
///
/// Keys are written in the normalised form produced by
/// [_normalizeSamplerToken]: lowercase, letters/digits and `+` only.
const Map<String, String> _samplerAliases = {
  'default': '',
  'automatic': '',
  'euler': 'euler',
  'eulera': 'euler_a',
  'eulerancestral': 'euler_a',
  'eulercfg++': 'euler_cfg_pp',
  'euleracfg++': 'euler_a_cfg_pp',
  'eulerge': 'euler_ge',
  'heun': 'heun',
  'dpm2': 'dpm2',
  'dpm2a': 'dpm2',
  'dpm2ancestral': 'dpm2',
  'dpm++2s': 'dpm++2s_a',
  'dpm++2sa': 'dpm++2s_a',
  'dpm++2m': 'dpm++2m',
  'dpm++2mv2': 'dpm++2mv2',
  'dpm++2msde': 'dpm++2m_sde',
  'dpm++2msdeheun': 'dpm++2m_sde',
  'dpm++2msdebt': 'dpm++2m_sde_bt',
  'dpm++sde': 'dpm++2m_sde',
  'dpm++sdeheun': 'dpm++2m_sde',
  // Tolerate names written without the '+' signs.
  'dpmpp2s': 'dpm++2s_a',
  'dpmpp2m': 'dpm++2m',
  'dpmpp2msde': 'dpm++2m_sde',
  'dpmppsde': 'dpm++2m_sde',
  'ddim': 'ddim_trailing',
  'ddimtrailing': 'ddim_trailing',
  'lcm': 'lcm',
  'tcd': 'tcd',
  'ipndm': 'ipndm',
  'ipndmv': 'ipndm_v',
  'resmultistep': 'res_multistep',
  'res2s': 'res_2s',
  'ersde': 'er_sde',
  'lms': 'lms',
  'lmskarras': 'lms',
};

/// Normalised scheduler alias -> sd.cpp `scheduler` ('' means "server
/// default").
const Map<String, String> _schedulerAliases = {
  'default': '',
  'automatic': '',
  'normal': 'normal',
  'discrete': 'discrete',
  'karras': 'karras',
  'exponential': 'exponential',
  'ays': 'ays',
  'alignyoursteps': 'ays',
  'gits': 'gits',
  'sgmuniform': 'sgm_uniform',
  'simple': 'simple',
  'smoothstep': 'smoothstep',
  'kloptimal': 'kl_optimal',
  'bongtangent': 'bong_tangent',
  'logitnormal': 'logit_normal',
  'beta': 'beta',
  'flux': 'flux',
  'flux2': 'flux2',
  'ltx2': 'ltx2',
};
