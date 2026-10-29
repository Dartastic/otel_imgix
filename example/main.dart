// Licensed under the Apache License, Version 2.0
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:otel_imgix/otel_imgix.dart';

/// Traces Imgix calls with OpenTelemetry.
///
/// `otel_imgix` depends on the OpenTelemetry API only, so the application
/// initializes an SDK once at startup. Wrap each Imgix call in
/// [tracedImgix]; the `invoke` callback makes the real call and reports what
/// came back, which is recorded on the span.
Future<void> main() async {
  await OTel.initialize(serviceName: 'imgix-example');

  // Wraps an Imgix call in a CLIENT span.
  final imgixId = await tracedImgix<String>(
    operation: 'sources.create',
    sourceId: 'source_8f3a2c',
    invoke: () async {
      // Make the Imgix call here, then report what it returned.
      const id = 'imgix_8f3a2c';
      return const ImgixCallResult(
          value: id,
          result: ImgixResult(
              sourceId: 'source_8f3a2c',
              paramCount: 3,
              signed: true,
              purgeKind: 'tag',
              originKind: 's3',
              outputFormat: 'w_p',
              cacheHit: true,
              aiAssetUsed: 'bg-remove',
              requestId: 'request_8f3a2c',
              statusCode: 201));
    },
  );
  OTelLog.info('tracedImgix sources.create returned $imgixId');

  // Calls that should not be traced, such as health checks, run inside
  // runWithoutImgixInstrumentationAsync.
  await runWithoutImgixInstrumentationAsync(
    () => tracedImgix<String>(
      operation: 'sources.create',
      sourceId: 'source_8f3a2c',
      invoke: () async {
        const id = 'imgix_8f3a2c';
        return const ImgixCallResult(
            value: id,
            result: ImgixResult(
                sourceId: 'source_8f3a2c',
                paramCount: 3,
                signed: true,
                purgeKind: 'tag',
                originKind: 's3',
                outputFormat: 'w_p',
                cacheHit: true,
                aiAssetUsed: 'bg-remove',
                requestId: 'request_8f3a2c',
                statusCode: 201));
      },
    ),
  );

  await OTel.shutdown();
}
