import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

/// Civitai API Client for Flutter/Dart (v2 Workflow API)
///
/// Based on the official documentation:
/// https://developer.civitai.com/orchestration/recipes/sdxl
///
/// Key changes from v1:
/// - Endpoint: /v2/consumer/workflows (was /v1/consumer/jobs)
/// - Uses steps[] with $type: "imageGen" workflow pattern
/// - Parameters: engine, ecosystem, operation (createImage/createVariant)
/// - Sample: sampleMethod (SdCppSampleMethod enum) + schedule (SdCppSchedule enum)
/// - LoRAs: input.loras { airUrn: strength } (was input.additionalNetworks)
/// - No clipSkip on SDXL (will 400)
/// - Response: steps[].output.images[] (was jobs[].result.blobUrl)
/// - Polling: use wait=60 for sync, wait=0 for async + GetWorkflow polling
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

  /// Jobs service instance (v2)
  JobsService get jobs => JobsService(this);
}

/// Image generation service (v2 workflow API)
class ImageService {
  final CivitaiClient _client;

  ImageService(this._client);

  /// Create an image generation job using v2 workflow API
  ///
  /// [input] - The input configuration for image generation
  /// [wait] - Seconds to wait for completion (0 = async, default 60)
  /// [timeout] - Custom timeout duration for polling
  /// [pollInterval] - Interval between polling requests (default: 2 seconds)
  ///
  /// Reference: https://developer.civitai.com/orchestration/recipes/sdxl
  Future<ImageResponse> create({
    required ImageInput input,
    int wait = 60,
    Duration? timeout,
    Duration pollInterval = const Duration(seconds: 2),
  }) async {
    // Validate input
    input.validate();

    // Determine engine/ecosystem from model URN
    final engine = input.engine ?? _detectEngine(input.model);
    final ecosystem = input.ecosystem ?? _detectEcosystem(input.model);
    final operation = input.operation ?? 'createImage';

    // Build the workflow step
    final workflowInput = <String, dynamic>{
      'engine': engine,
      'ecosystem': ecosystem,
      'operation': operation,
      'model': input.model,
      'prompt': input.params.prompt,
      if (input.params.negativePrompt != null && input.params.negativePrompt!.isNotEmpty)
        'negativePrompt': input.params.negativePrompt,
      'width': input.params.width,
      'height': input.params.height,
      'cfgScale': input.params.cfgScale ?? 7,
      'steps': input.params.steps ?? 25,
      // v2 uses sampleMethod/schedule for sdcpp, sampler/scheduler for comfy
      if (engine == 'comfy') ...[
        if (input.params.scheduler != null) 'sampler': input.params.scheduler,
        // comfy doesn't use schedule, but we can pass scheduler as string
        if (input.params.schedule != null) 'scheduler': input.params.schedule,
      ] else ...[
        // sdcpp (default): sampleMethod + schedule
        if (input.params.sampleMethod != null) 'sampleMethod': input.params.sampleMethod,
        if (input.params.schedule != null) 'schedule': input.params.schedule,
      ],
      if (input.params.seed != null) 'seed': input.params.seed,
      // LoRAs: directly in input as { airUrn: strength }
      if (input.loras != null && input.loras!.isNotEmpty) 'loras': input.loras,
      if (input.embeddings != null && input.embeddings!.isNotEmpty)
        'embeddings': input.embeddings,
      if (input.quantity != null) 'quantity': input.quantity,
    };

    // Build the full workflow body
    final body = {
      'steps': [
        {
          '\$type': 'imageGen',
          'input': workflowInput,
        }
      ],
    };

    final uri = Uri.parse(
        '${_client.baseUrl}/v2/consumer/workflows?wait=$wait');

    // Create workflow
    final response = await http.post(
      uri,
      headers: _client._headers,
      body: json.encode(body),
    );

    if (response.statusCode != 200 && response.statusCode != 201 && response.statusCode != 202) {
      throw CivitaiException(
        response.statusCode,
        'Failed to create workflow: ${response.body}',
      );
    }

    final responseData = json.decode(response.body);

    // Parse the response
    final imageResponse = ImageResponse.fromJson(responseData);

    // If wait was used and the job completed, return immediately
    if (wait > 0 && imageResponse.status == 'succeeded') {
      return imageResponse;
    }

    // Otherwise poll for completion
    if (wait == 0 || imageResponse.status != 'succeeded') {
      final workflowId = responseData['id'] ?? responseData['workflowId'];
      if (workflowId != null) {
        return await _pollForWorkflowCompletion(
          workflowId,
          timeout: timeout ?? _client.defaultTimeout,
          interval: pollInterval,
        );
      }
    }

    return imageResponse;
  }

  /// Poll for workflow completion
  Future<ImageResponse> _pollForWorkflowCompletion(
    String workflowId, {
    required Duration timeout,
    Duration interval = const Duration(seconds: 2),
  }) async {
    final startTime = DateTime.now();

    while (DateTime.now().difference(startTime) < timeout) {
      try {
        final response = await _client.jobs.getWorkflow(workflowId);
        final status = response.status;

        if (status == 'succeeded') {
          return response;
        } else if (status == 'failed') {
          throw CivitaiException(0,
              'Workflow $workflowId failed: ${response.errorMessage ?? "Unknown error"}');
        }
      } catch (e) {
        // Continue polling on transient errors
        if (e is CivitaiException) rethrow;
      }

      await Future.delayed(interval);
    }

    throw TimeoutException(
      'Workflow polling timeout after ${timeout.inMinutes} minutes. '
      'Use GetWorkflow endpoint to check status.',
    );
  }

  String _detectEngine(String model) {
    return 'sdcpp'; // Default engine for SDXL
  }

  String _detectEcosystem(String model) {
    if (model.contains('sdxl')) return 'sdxl';
    if (model.contains('sd1') || model.contains('sd_1')) return 'sd1';
    return 'sdxl';
  }
}

/// Jobs service (v2)
class JobsService {
  final CivitaiClient _client;

  JobsService(this._client);

  /// Get workflow status by ID (v2)
  Future<ImageResponse> getWorkflow(String workflowId) async {
    final response = await http.get(
      Uri.parse('${_client.baseUrl}/v2/consumer/workflows/$workflowId'),
      headers: _client._headers,
    );

    if (response.statusCode != 200 && response.statusCode != 202) {
      throw CivitaiException(
        response.statusCode,
        'Failed to get workflow: ${response.body}',
      );
    }

    return ImageResponse.fromJson(json.decode(response.body));
  }

  /// Legacy: Get job by token (v1, kept for backward compatibility)
  @Deprecated('Use getWorkflow instead (v2 API)')
  Future<ImageResponse> get({String? token, String? jobId}) async {
    if (token == null && jobId == null) {
      throw ArgumentError('Either token or jobId must be provided');
    }

    if (token != null) {
      // Try v2 first, fallback to v1
      try {
        // v2 uses workflow query
        final response = await http.get(
          Uri.parse(
              '${_client.baseUrl}/v2/consumer/workflows?token=$token'),
          headers: _client._headers,
        );

        if (response.statusCode == 200 || response.statusCode == 202) {
          return ImageResponse.fromJson(json.decode(response.body));
        }
      } catch (_) {}

      // v1 fallback
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

      return _legacyImageResponseFromJson(json.decode(response.body));
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
        steps: [
          WorkflowStep(
            name: '0',
            type: 'imageGen',
            status: data['status'] ?? 'unknown',
            output: WorkflowOutput(
              images: [
                ImageResult.fromJobResult(data),
              ],
            ),
          ),
        ],
      );
    }
  }

  /// Legacy parser for v1 response format
  ImageResponse _legacyImageResponseFromJson(Map<String, dynamic> json) {
    final jobs = (json['jobs'] as List?)
            ?.map((job) => Job.fromJson(job))
            .toList() ??
        [];
    return ImageResponse(
      token: json['token'] ?? '',
      status: jobs.every((j) => j.imageUrl != null) ? 'succeeded' : 'processing',
      steps: jobs.asMap().entries.map((entry) {
        final idx = entry.key;
        final job = entry.value;
        return WorkflowStep(
          name: idx.toString(),
          type: 'imageGen',
          status: job.imageUrl != null ? 'succeeded' : 'processing',
          output: WorkflowOutput(
            images: [
              ImageResult(
                id: job.jobId,
                url: job.imageUrl ?? '',
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  /// Query workflows (v2)
  Future<QueryWorkflowsResult> query({
    required Map<String, dynamic> queryRequest,
    bool detailed = false,
  }) async {
    final response = await http.post(
      Uri.parse(
          '${_client.baseUrl}/v2/consumer/workflows/query?detailed=$detailed'),
      headers: _client._headers,
      body: json.encode(queryRequest),
    );

    if (response.statusCode != 200 && response.statusCode != 202) {
      throw CivitaiException(
        response.statusCode,
        'Failed to query workflows: ${response.body}',
      );
    }

    return QueryWorkflowsResult.fromJson(json.decode(response.body));
  }
}

/// Image generation input data for v2 workflow API
class ImageInput {
  final String model;
  final ImageParams params;
  final Map<String, double>? loras;
  final List<String>? embeddings;
  final String? engine;
  final String? ecosystem;
  final String? operation;
  final int? quantity;

  ImageInput({
    required this.model,
    required this.params,
    this.loras,
    this.embeddings,
    this.engine,
    this.ecosystem,
    this.operation,
    this.quantity,
  });

  void validate() {
    if (model.isEmpty) {
      throw ArgumentError('Model cannot be empty');
    }
    params.validate();
  }
}

/// Image generation parameters for v2 workflow API
///
/// Supported parameters based on SDK:
/// https://developer.civitai.com/orchestration/recipes/sdxl#text-to-image
class ImageParams {
  final String prompt;
  final String? negativePrompt;
  final int width;
  final int height;
  final int? steps;
  final double? cfgScale;
  final int? seed;
  /// sdcpp: sampleMethod (e.g. "euler", "dpmpp_2m" from SdCppSampleMethod)
  final String? sampleMethod;
  /// sdcpp: schedule (e.g. "discrete", "karras" from SdCppSchedule)
  /// comfy: scheduler (e.g. "karras", "normal" from ComfyScheduler)
  final String? schedule;
  /// comfy: sampler (e.g. "dpmpp_2m" from ComfySampler)
  /// Only used when engine is "comfy"
  final String? sampler;

  ImageParams({
    required this.prompt,
    this.negativePrompt,
    required this.width,
    required this.height,
    this.steps,
    this.cfgScale,
    this.seed,
    this.sampleMethod,
    this.schedule,
    this.sampler,
  });

  void validate() {
    if (prompt.isEmpty) {
      throw ArgumentError('Prompt cannot be empty');
    }
    if (width % 16 != 0) {
      throw ArgumentError('Width must be divisible by 16');
    }
    if (height % 16 != 0) {
      throw ArgumentError('Height must be divisible by 16');
    }
  }
}

/// Image generation response for v2 workflow API
///
/// Response format:
/// ```json
/// {
///   "status": "succeeded",
///   "steps": [{
///     "name": "0",
///     "$type": "imageGen",
///     "status": "succeeded",
///     "output": {
///       "images": [
///         { "id": "blob_...", "url": "https://.../signed.jpeg" }
///       ]
///     }
///   }]
/// }
/// ```
class ImageResponse {
  final String token;
  final String? status;
  final List<WorkflowStep> steps;
  final String? errorMessage;
  final String? id;

  ImageResponse({
    this.token = '',
    this.status,
    this.steps = const [],
    this.errorMessage,
    this.id,
  });

  factory ImageResponse.fromJson(Map<String, dynamic> json) {
    List<WorkflowStep> steps = [];
    if (json['steps'] != null) {
      steps = (json['steps'] as List)
          .map((s) => WorkflowStep.fromJson(s))
          .toList();
    }

    return ImageResponse(
      id: json['id'],
      token: json['token'] ?? '',
      status: json['status'],
      steps: steps,
      errorMessage: json['errorMessage'],
    );
  }

  /// Get all image results from completed steps
  List<ImageResult> get images {
    final results = <ImageResult>[];
    for (final step in steps) {
      if (step.status == 'succeeded' && step.output != null) {
        results.addAll(step.output!.images);
      }
    }
    return results;
  }

  /// Backward-compatible: get first image URL (mimics old Job.imageUrl)
  String? get firstImageUrl {
    final imgs = images;
    return imgs.isNotEmpty ? imgs.first.url : null;
  }
}

/// A single step in the workflow
class WorkflowStep {
  final String name;
  final String type;
  final String status;
  final WorkflowOutput? output;

  WorkflowStep({
    required this.name,
    required this.type,
    required this.status,
    this.output,
  });

  factory WorkflowStep.fromJson(Map<String, dynamic> json) {
    return WorkflowStep(
      name: json['name'] ?? '',
      type: json['\$type'] ?? '',
      status: json['status'] ?? 'unknown',
      output: json['output'] != null
          ? WorkflowOutput.fromJson(json['output'])
          : null,
    );
  }
}

/// Output of a workflow step
class WorkflowOutput {
  final List<ImageResult> images;

  WorkflowOutput({
    this.images = const [],
  });

  factory WorkflowOutput.fromJson(Map<String, dynamic> json) {
    return WorkflowOutput(
      images: (json['images'] as List?)
              ?.map((img) => ImageResult.fromJson(img))
              .toList() ??
          [],
    );
  }
}

/// Result image data
class ImageResult {
  final String id;
  final String url;

  ImageResult({
    required this.id,
    required this.url,
  });

  factory ImageResult.fromJson(Map<String, dynamic> json) {
    return ImageResult(
      id: json['id'] ?? '',
      url: json['url'] ?? '',
    );
  }
}

/// Query workflows result
class QueryWorkflowsResult {
  final List<ImageResponse> workflows;
  final String? cursor;

  QueryWorkflowsResult({
    required this.workflows,
    this.cursor,
  });

  factory QueryWorkflowsResult.fromJson(Map<String, dynamic> json) {
    return QueryWorkflowsResult(
      workflows: (json['workflows'] as List?)
              ?.map((w) => ImageResponse.fromJson(w))
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

// ---------------------------------------------------------------------------
// Legacy types kept for backward compatibility
// ---------------------------------------------------------------------------

/// @Deprecated Legacy Job class (v1). Use ImageResult instead.
@Deprecated('Use ImageResult from workflow response (v2)')
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

    if (result is Map<String, dynamic>) {
      final url = (result as Map<String, dynamic>)['blobUrl'];
      return url is String ? url : null;
    }

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

/// @Deprecated Legacy query result
@Deprecated('Use QueryWorkflowsResult instead (v2)')
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

/// @Deprecated Legacy ControlNet
@Deprecated('ControlNet not supported in v2 SDK yet')
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
      const validPreprocessors = [
        'Canny',
        'DepthZoe',
        'SoftedgePidinet',
        'Rembg'
      ];
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
