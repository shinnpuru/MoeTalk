import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

/// Civitai API Client for Flutter/Dart
class CivitaiClient {
  final String apiToken;
  final String baseUrl;
  final Duration defaultTimeout;

  CivitaiClient({
    required this.apiToken,
    this.baseUrl = 'https://orchestration.civitai.com',
    this.defaultTimeout = const Duration(minutes: 5),
  }) {
    if (apiToken.isEmpty) {
      throw ArgumentError('API token cannot be empty');
    }
  }

  /// Create a factory constructor for dev environment
  factory CivitaiClient.dev({required String apiToken}) {
    return CivitaiClient(
      apiToken: apiToken,
      baseUrl: 'https://orchestration-dev.civitai.com',
    );
  }

  Map<String, String> get _headers => {
        'Authorization': 'Bearer $apiToken',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  /// Image service instance
  ImageService get image => ImageService(this);

  /// Jobs service instance
  JobsService get jobs => JobsService(this);

  /// Text-to-speech service instance
  TextToSpeechService get textToSpeech => TextToSpeechService(this);
}

/// Civitai orchestration text-to-speech recipe service.
class TextToSpeechService {
  final CivitaiClient _client;

  TextToSpeechService(this._client);

  Future<String> createVoiceClone({
    required String text,
    required String refAudioUrl,
    String? refText,
    String language = 'Auto',
    Duration? timeout,
  }) async {
    if (text.trim().isEmpty) {
      throw ArgumentError('Text cannot be empty');
    }
    if (refAudioUrl.trim().isEmpty) {
      throw ArgumentError('Voice reference audio URL is not configured');
    }

    final transcript = refText?.trim() ?? '';
    final input = {
      'text': text,
      'engine': 'custom',
      'refAudioUrl': refAudioUrl.trim(),
      if (transcript.isNotEmpty) 'refText': transcript,
      'xVectorOnlyMode': transcript.isEmpty,
      'language': language,
    };
    final response = await http
        .post(
          Uri.parse(
            '${_client.baseUrl}/v2/consumer/workflows?wait=0',
          ),
          headers: _client._headers,
          body: json.encode({
            'steps': [
              {
                '\$type': 'textToSpeech',
                'input': input,
              },
            ],
          }),
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode != 200 &&
        response.statusCode != 201 &&
        response.statusCode != 202) {
      throw CivitaiException(
        response.statusCode,
        _problemMessage(response.body, 'Failed to submit text-to-speech'),
      );
    }

    final submitted = _decodeObject(response.body);
    final inlineAudioUrl = _audioUrl(submitted);
    if (inlineAudioUrl != null) {
      return inlineAudioUrl;
    }

    final workflowId = submitted['id']?.toString();
    if (workflowId == null || workflowId.isEmpty) {
      throw CivitaiException(
        response.statusCode,
        'Civitai did not return a workflow ID',
      );
    }

    return _pollForAudio(
      workflowId,
      timeout: timeout ?? _client.defaultTimeout,
    );
  }

  Future<String> _pollForAudio(
    String workflowId, {
    required Duration timeout,
  }) async {
    final startedAt = DateTime.now();
    var pollCount = 0;

    while (DateTime.now().difference(startedAt) < timeout) {
      final delay = switch (pollCount) {
        0 => const Duration(seconds: 2),
        1 => const Duration(seconds: 5),
        2 => const Duration(seconds: 10),
        3 => const Duration(seconds: 15),
        _ => const Duration(seconds: 30),
      };
      pollCount++;
      await Future.delayed(delay);

      final response = await http
          .get(
            Uri.parse('${_client.baseUrl}/v2/consumer/workflows/$workflowId'),
            headers: _client._headers,
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode != 200 && response.statusCode != 202) {
        throw CivitaiException(
          response.statusCode,
          _problemMessage(response.body, 'Failed to query text-to-speech'),
        );
      }

      final workflow = _decodeObject(response.body);
      final audioUrl = _audioUrl(workflow);
      if (audioUrl != null) {
        return audioUrl;
      }

      final status = workflow['status']?.toString().toLowerCase();
      if (const {'failed', 'expired', 'canceled'}.contains(status)) {
        throw CivitaiException(
          response.statusCode,
          _workflowFailureMessage(workflow, status!),
        );
      }
      if (status == 'succeeded') {
        throw CivitaiException(
          response.statusCode,
          'Text-to-speech succeeded without an audio URL',
        );
      }
    }

    throw TimeoutException(
      'Text-to-speech timed out after ${timeout.inMinutes} minutes',
    );
  }

  static Map<String, dynamic> _decodeObject(String body) {
    final decoded = json.decode(body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Civitai returned an invalid JSON object');
    }
    return decoded;
  }

  static String? _audioUrl(Map<String, dynamic> data) {
    final directBlob = data['audioBlob'];
    final directUrl = _availableBlobUrl(directBlob);
    if (directUrl != null) return directUrl;

    final steps = data['steps'];
    if (steps is! List) return null;
    for (final step in steps) {
      if (step is! Map) continue;
      final output = step['output'];
      if (output is! Map) continue;
      final audioBlob = output['audioBlob'];
      final audioUrl = _availableBlobUrl(audioBlob);
      if (audioUrl != null) return audioUrl;
      final blobs = output['blobs'];
      if (blobs is List) {
        for (final blob in blobs) {
          final blobUrl = _availableBlobUrl(blob);
          if (blob is Map && blob['type'] == 'audio' && blobUrl != null) {
            return blobUrl;
          }
        }
      }
    }
    return null;
  }

  static String? _availableBlobUrl(dynamic blob) {
    if (blob is! Map || blob['available'] == false || blob['url'] is! String) {
      return null;
    }
    final url = blob['url'] as String;
    return url.isEmpty ? null : url;
  }

  static String _problemMessage(String body, String fallback) {
    try {
      final problem = _decodeObject(body);
      final messages = <String>[];
      final errors = problem['errors'];
      if (errors is Map) {
        for (final value in errors.values) {
          if (value is List) {
            messages.addAll(value.map((item) => item.toString()));
          } else if (value != null) {
            messages.add(value.toString());
          }
        }
      }
      final detail = problem['detail']?.toString();
      if (detail != null && detail.isNotEmpty) messages.add(detail);
      if (messages.isNotEmpty) return messages.join('; ');
      return problem['title']?.toString() ?? fallback;
    } catch (_) {
      return fallback;
    }
  }

  static String _workflowFailureMessage(
    Map<String, dynamic> workflow,
    String status,
  ) {
    final steps = workflow['steps'];
    if (steps is List) {
      for (final step in steps.reversed) {
        if (step is Map) {
          final reason = step['reason'] ?? step['blockedReason'];
          if (reason != null && reason.toString().isNotEmpty) {
            return 'Text-to-speech $status: $reason';
          }
        }
      }
    }
    return 'Text-to-speech $status';
  }
}

/// Image generation service
class ImageService {
  final CivitaiClient _client;

  ImageService(this._client);

  /// Create an image generation job
  /// 
  /// [input] - The input configuration for image generation
  /// [wait] - Whether to wait for the job to complete (long polling)
  /// [timeout] - Custom timeout duration (defaults to client's defaultTimeout)
  /// [pollInterval] - Interval between polling requests (default: 1 second)
  Future<ImageResponse> create({
    required ImageInput input,
    bool wait = false,
    Duration? timeout,
    Duration pollInterval = const Duration(seconds: 1),
  }) async {
    // Validate input
    input.validate();

    // Determine base model from model URN
    final baseModel = input.model.contains('sdxl') ? 'SDXL' : 'SD_1_5';

    // Build job input
    final jobInput = {
      '\$type': 'textToImage',
      'baseModel': baseModel,
      'model': input.model,
      'params': input.params.toJson(),
      if (input.additionalNetworks != null)
        'additionalNetworks': input.additionalNetworks,
      if (input.controlNets != null)
        'controlNets': input.controlNets?.map((cn) => cn.toJson()).toList(),
      if (input.callbackUrl != null) 'callbackUrl': input.callbackUrl,
      if (input.quantity != null) 'quantity': input.quantity,
      if (input.properties != null) 'properties': input.properties,
    };

    // Create job
    final response = await http.post(
      Uri.parse('${_client.baseUrl}/v1/consumer/jobs'),
      headers: _client._headers,
      body: json.encode(jobInput),
    );

    if (response.statusCode != 200 && response.statusCode != 201 && response.statusCode != 202) {
      throw CivitaiException(
        response.statusCode,
        'Failed to create job: ${response.body}',
      );
    }

    final responseData = json.decode(response.body);
    final imageResponse = ImageResponse.fromJson(responseData);

    // If wait is true, poll for completion
    if (wait) {
      return await _pollForJobCompletion(
        imageResponse.token,
        timeout: timeout ?? _client.defaultTimeout,
        interval: pollInterval,
      );
    }

    return imageResponse;
  }

  /// Poll for job completion with timeout
  Future<ImageResponse> _pollForJobCompletion(
    String token, {
    required Duration timeout,
    Duration interval = const Duration(seconds: 1),
  }) async {
    final startTime = DateTime.now();
    ImageResponse? lastResponse;
    final completedJobs = <String, Job>{};

    while (DateTime.now().difference(startTime) < timeout) {
      try {
        final response = await _client.jobs.get(token: token);
        lastResponse = response;

        // Check if all jobs are completed
        for (final job in response.jobs) {
          if (!completedJobs.containsKey(job.jobId)) {
            if (job.imageUrl != null) {
              completedJobs[job.jobId] = job;
            }
          }
        }

        // All jobs completed
        if (completedJobs.length >= response.jobs.length) {
          return ImageResponse(
            token: response.token,
            jobs: completedJobs.values.toList(),
          );
        }
      } catch (e) {
        // Continue polling on error
        print('Polling error: $e');
      }

      await Future.delayed(interval);
    }

    // Timeout reached
    if (completedJobs.isNotEmpty) {
      return ImageResponse(
        token: lastResponse!.token,
        jobs: completedJobs.values.toList(),
      );
    }

    if (lastResponse != null) {
      print('Warning: Job did not complete within ${timeout.inMinutes} minutes');
      return lastResponse;
    }

    throw TimeoutException(
      'Job polling timeout after ${timeout.inMinutes} minutes',
    );
  }
}

/// Jobs service
class JobsService {
  final CivitaiClient _client;

  JobsService(this._client);

  /// Get job details by token or job ID
  Future<ImageResponse> get({String? token, String? jobId}) async {
    if (token == null && jobId == null) {
      throw ArgumentError('Either token or jobId must be provided');
    }

    if (token != null) {
      final response = await http.get(
        Uri.parse('${_client.baseUrl}/v1/consumer/jobs?token=$token'),
        headers: _client._headers,
      );

      if (response.statusCode != 200 && response.statusCode != 202) {
        throw CivitaiException(
          response.statusCode,
          'Failed to get job: ${response.body}',
        );
      }

      return ImageResponse.fromJson(json.decode(response.body));
    } else {
      final response = await http.get(
        Uri.parse('${_client.baseUrl}/v1/consumer/jobs/$jobId'),
        headers: _client._headers,
      );

      if (response.statusCode != 200 && response.statusCode != 202) {
        throw CivitaiException(
          response.statusCode,
          'Failed to get job: ${response.body}',
        );
      }

      final data = json.decode(response.body);
      return ImageResponse(
        token: '',
        jobs: [Job.fromJson(data)],
      );
    }
  }

  /// Query jobs
  Future<QueryJobsResult> query({
    required Map<String, dynamic> queryRequest,
    bool detailed = false,
  }) async {
    final response = await http.post(
      Uri.parse('${_client.baseUrl}/v1/consumer/jobs/query?detailed=$detailed'),
      headers: _client._headers,
      body: json.encode(queryRequest),
    );

    if (response.statusCode != 200 && response.statusCode != 202) {
      throw CivitaiException(
        response.statusCode,
        'Failed to query jobs: ${response.body}',
      );
    }

    return QueryJobsResult.fromJson(json.decode(response.body));
  }

  /// Cancel a job
  Future<void> cancel(String jobId) async {
    final response = await http.delete(
      Uri.parse('${_client.baseUrl}/v1/consumer/jobs/$jobId'),
      headers: _client._headers,
    );

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw CivitaiException(
        response.statusCode,
        'Failed to cancel job: ${response.body}',
      );
    }
  }
}

/// Image generation input
class ImageInput {
  final String model;
  final ImageParams params;
  final Map<String, dynamic>? additionalNetworks;
  final List<ControlNet>? controlNets;
  final String? callbackUrl;
  final int? quantity;
  final Map<String, dynamic>? properties;

  ImageInput({
    required this.model,
    required this.params,
    this.additionalNetworks,
    this.controlNets,
    this.callbackUrl,
    this.quantity,
    this.properties,
  });

  void validate() {
    if (model.isEmpty) {
      throw ArgumentError('Model cannot be empty');
    }
    params.validate();
    controlNets?.forEach((cn) => cn.validate());
  }
}

/// Image generation parameters
class ImageParams {
  final String prompt;
  final String? negativePrompt;
  final String? scheduler;
  final int? steps;
  final double? cfgScale;
  final int width;
  final int height;
  final int? seed;
  final int? clipSkip;

  ImageParams({
    required this.prompt,
    this.negativePrompt,
    this.scheduler,
    this.steps,
    this.cfgScale,
    required this.width,
    required this.height,
    this.seed,
    this.clipSkip,
  });

  void validate() {
    if (prompt.isEmpty) {
      throw ArgumentError('Prompt cannot be empty');
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'prompt': prompt,
      if (negativePrompt != null) 'negativePrompt': negativePrompt,
      if (scheduler != null) 'scheduler': scheduler,
      if (steps != null) 'steps': steps,
      if (cfgScale != null) 'cfgScale': cfgScale,
      'width': width,
      'height': height,
      if (seed != null) 'seed': seed,
      if (clipSkip != null) 'clipSkip': clipSkip,
    };
  }
}

/// ControlNet configuration
class ControlNet {
  final String? preprocessor;
  final double? weight;
  final int? startStep;
  final int? endStep;
  final String? imageUrl;
  final String? blobKey;

  ControlNet({
    this.preprocessor,
    this.weight,
    this.startStep,
    this.endStep,
    this.imageUrl,
    this.blobKey,
  });

  void validate() {
    if (preprocessor != null) {
      const validPreprocessors = ['Canny', 'DepthZoe', 'SoftedgePidinet', 'Rembg'];
      if (!validPreprocessors.contains(preprocessor)) {
        throw ArgumentError('Invalid preprocessor: $preprocessor');
      }
    }
  }

  Map<String, dynamic> toJson() {
    return {
      if (preprocessor != null) 'preprocessor': preprocessor,
      if (weight != null) 'weight': weight,
      if (startStep != null) 'startStep': startStep,
      if (endStep != null) 'endStep': endStep,
      if (imageUrl != null) 'imageUrl': imageUrl,
      if (blobKey != null) 'blobKey': blobKey,
    };
  }
}

/// Image generation response
class ImageResponse {
  final String token;
  final List<Job> jobs;

  ImageResponse({
    required this.token,
    required this.jobs,
  });

  factory ImageResponse.fromJson(Map<String, dynamic> json) {
    return ImageResponse(
      token: json['token'] ?? '',
      jobs: (json['jobs'] as List?)
              ?.map((job) => Job.fromJson(job))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'token': token,
      'jobs': jobs.map((job) => job.toJson()).toList(),
    };
  }
}

/// Job details
class Job {
  final String jobId;
  final double? cost;
  final dynamic result;
  final bool? scheduled;

  Job({
    required this.jobId,
    this.cost,
    this.result,
    this.scheduled,
  });

  factory Job.fromJson(Map<String, dynamic> json) {
    return Job(
      jobId: json['jobId'],
      cost: json['cost']?.toDouble(),
      result: json['result'],
      scheduled: json['scheduled'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'jobId': jobId,
      if (cost != null) 'cost': cost,
      if (result != null) 'result': result,
      if (scheduled != null) 'scheduled': scheduled,
    };
  }

  /// Get the generated image URL from result
  String? get imageUrl {
    if (result == null) return null;

    // Case 1: result is a map like {"blobUrl": "..."}
    if (result is Map<String, dynamic>) {
      final url = (result as Map<String, dynamic>)['blobUrl'];
      return url is String ? url : null;
    }

    // Case 2: result is a list like [{"blobUrl": "..."}, ...]
    if (result is List) {
      for (final item in (result as List)) {
        if (item is Map<String, dynamic>) {
          final url = item['blobUrl'];
          if (url is String && url.isNotEmpty) return url;
        }
      }
    }

    return null;
  }
}

/// Query jobs result
class QueryJobsResult {
  final List<Job> jobs;
  final String? cursor;

  QueryJobsResult({
    required this.jobs,
    this.cursor,
  });

  factory QueryJobsResult.fromJson(Map<String, dynamic> json) {
    return QueryJobsResult(
      jobs: (json['jobs'] as List?)
              ?.map((job) => Job.fromJson(job))
              .toList() ??
          [],
      cursor: json['cursor'],
    );
  }
}

/// Civitai API exception
class CivitaiException implements Exception {
  final int statusCode;
  final String message;

  CivitaiException(this.statusCode, this.message);

  @override
  String toString() => 'CivitaiException: $statusCode - $message';
}
