// Licensed under the Dartastic Pro Software License Agreement.
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';

import 'otel_imgix_suppression.dart';

const _tracerName = 'dartastic_otel_libs_imgix';

Tracer _tracer() => OTel.tracerProvider().getTracer(_tracerName);

class ImgixResult {
  const ImgixResult({
    this.sourceId,
    this.paramCount,
    this.signed,
    this.purgeKind,
    this.originKind,
    this.outputFormat,
    this.cacheHit,
    this.aiAssetUsed,
    this.requestId,
    this.statusCode,
  });

  /// Imgix Source id (handle).
  final String? sourceId;

  /// Number of rendering parameters on the URL (each transform query
  /// param is metered against the monthly transform allowance).
  final int? paramCount;

  /// Whether the rendering URL was signed (signed URLs gate origin
  /// access; misconfig is a common 4xx cause).
  final bool? signed;

  /// `tag` / `url` / `source` for purge endpoints — tag purges have a
  /// larger cache-invalidation blast radius.
  final String? purgeKind;

  /// `s3` / `gcs` / `azure` / `web_folder` / `web_proxy` / `manual`.
  final String? originKind;

  /// `w_p`, `auto=format`, `jpg`, `webp`, `avif` — what Imgix served.
  final String? outputFormat;

  /// `X-Imgix-Cache: HIT|MISS|REVALIDATED` shadow.
  final bool? cacheHit;

  /// AI Asset feature used (`bg-remove`, `face-detect`,
  /// `text-extraction`) — premium add-on, billed separately.
  final String? aiAssetUsed;

  /// `X-Imgix-Request-Id`.
  final String? requestId;

  final int? statusCode;
}

class ImgixCallResult<T> {
  const ImgixCallResult({required this.value, this.result});
  final T value;
  final ImgixResult? result;
}

/// Wraps an Imgix call in a CLIENT span. [operation] is one of
/// `render`, `render.signed`, `purge.url`, `purge.tag`, `sources.list`,
/// `sources.create`, `sources.update`, `assets.list`,
/// `assets.upload`, `assets.delete`, `report.usage`, `webhooks.create`.
Future<T> tracedImgix<T>({
  required String operation,
  required Future<ImgixCallResult<T>> Function() invoke,
  String? sourceId,
}) async {
  if (imgixInstrumentationSuppressed()) {
    final r = await invoke();
    return r.value;
  }
  final m = <String, Object>{
    'rpc.system': 'imgix',
    'rpc.method': operation,
    'imgix.operation': operation,
  };
  if (sourceId != null) m['imgix.source.id'] = sourceId;

  final span = _tracer().startSpan(
    'imgix $operation',
    kind: SpanKind.client,
    attributes: OTel.attributesFromMap(m),
  );
  try {
    final r = await invoke();
    if (r.result != null) {
      final extras = <Attribute<Object>>[];
      if (r.result!.sourceId != null) {
        extras.add(OTel.attributeString(
          'imgix.source.id',
          r.result!.sourceId!,
        ));
      }
      if (r.result!.paramCount != null) {
        extras.add(OTel.attributeInt(
          'imgix.param_count',
          r.result!.paramCount!,
        ));
      }
      if (r.result!.signed != null) {
        extras.add(OTel.attributeBool('imgix.signed', r.result!.signed!));
      }
      if (r.result!.purgeKind != null) {
        extras.add(OTel.attributeString(
          'imgix.purge.kind',
          r.result!.purgeKind!,
        ));
      }
      if (r.result!.originKind != null) {
        extras.add(OTel.attributeString(
          'imgix.origin.kind',
          r.result!.originKind!,
        ));
      }
      if (r.result!.outputFormat != null) {
        extras.add(OTel.attributeString(
          'imgix.output_format',
          r.result!.outputFormat!,
        ));
      }
      if (r.result!.cacheHit != null) {
        extras.add(OTel.attributeBool(
          'imgix.cache.hit',
          r.result!.cacheHit!,
        ));
      }
      if (r.result!.aiAssetUsed != null) {
        extras.add(OTel.attributeString(
          'imgix.ai_asset',
          r.result!.aiAssetUsed!,
        ));
      }
      if (r.result!.requestId != null) {
        extras.add(OTel.attributeString(
          'imgix.request.id',
          r.result!.requestId!,
        ));
      }
      if (r.result!.statusCode != null) {
        extras.add(OTel.attributeInt(
          'http.response.status_code',
          r.result!.statusCode!,
        ));
        if (r.result!.statusCode! >= 400) {
          span.setStatus(
            SpanStatusCode.Error,
            'Imgix HTTP ${r.result!.statusCode}',
          );
        }
      }
      if (extras.isNotEmpty) span.addAttributes(OTel.attributes(extras));
    }
    return r.value;
  } catch (e, st) {
    span.addAttributes(OTel.attributes([
      OTel.attributeString(
        ErrorResource.errorType.key,
        e.runtimeType.toString(),
      ),
    ]));
    span.recordException(e, stackTrace: st);
    span.setStatus(SpanStatusCode.Error, e.toString());
    rethrow;
  } finally {
    span.end();
  }
}
