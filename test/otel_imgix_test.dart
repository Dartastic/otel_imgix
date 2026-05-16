// Licensed under the Apache License, Version 2.0
// Copyright 2025, Mindful Software LLC, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:dartastic_opentelemetry/testing.dart';
import 'package:otel_imgix/otel_imgix.dart';
import 'package:test/test.dart';

void main() {
  late TestHarness harness;
  late InMemorySpanExporter spans;

  setUpAll(() async {
    harness = await maybeInitializeOtelForTest(
      serviceName: 'otel_imgix-test',
    );
    spans = harness.spans;
  });

  setUp(() => harness.clear());

  Map<String, Object> attrsOf(Span s) =>
      {for (final a in s.attributes.toList()) a.key: a.value};

  test('render records params + signed + ai asset', () async {
    await tracedImgix<String>(
      operation: 'render.signed',
      sourceId: 'src-1',
      invoke: () async => const ImgixCallResult(
        value: 'ok',
        result: ImgixResult(
          sourceId: 'src-1',
          paramCount: 6,
          signed: true,
          originKind: 's3',
          outputFormat: 'avif',
          cacheHit: true,
          aiAssetUsed: 'bg-remove',
          statusCode: 200,
        ),
      ),
    );
    final a = attrsOf(spans.findSpanByName('imgix render.signed')!);
    expect(a['imgix.source.id'], 'src-1');
    expect(a['imgix.param_count'], 6);
    expect(a['imgix.signed'], true);
    expect(a['imgix.output_format'], 'avif');
    expect(a['imgix.cache.hit'], true);
    expect(a['imgix.ai_asset'], 'bg-remove');
  });

  test('purge.tag recorded with blast-radius kind', () async {
    await tracedImgix<String>(
      operation: 'purge.tag',
      invoke: () async => const ImgixCallResult(
        value: 'ok',
        result: ImgixResult(purgeKind: 'tag', statusCode: 202),
      ),
    );
    final a = attrsOf(spans.findSpanByName('imgix purge.tag')!);
    expect(a['imgix.purge.kind'], 'tag');
  });

  test('suppression skips spans', () async {
    await runWithoutImgixInstrumentationAsync(() async {
      await tracedImgix<String>(
        operation: 'sources.list',
        invoke: () async => const ImgixCallResult(value: 'v'),
      );
    });
    expect(spans.findSpansStartingWith('imgix '), isEmpty);
  });
}
