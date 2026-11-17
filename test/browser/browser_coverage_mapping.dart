import 'dart:convert';
import 'dart:io';

import 'package:source_maps/source_maps.dart';

import 'browser_check_failure.dart';

final _newline = RegExp('\n');

/// Map Chrome's measured ranges through the compiler's original Dart locations.
Future<void> writeDartCoverage(File bundle, List<Object?> functions, File output) async {
  final mapping = switch (parse(await File('${bundle.path}.map').readAsString())) {
    final SingleMapping single => single,
    _ => throw const BrowserCheckFailure('Compiler wrote an unsupported source map'),
  };
  final text = await bundle.readAsString();
  final lineOffsets = [0, ..._newline.allMatches(text).map((match) => match.end)];
  final source = File('lib/src/storage/web_download_helper.dart').absolute.uri;
  final mapUri = File('${bundle.path}.map').absolute.uri;
  final sourceIds = <int>{
    for (int index = 0; index < mapping.urls.length; index++)
      if (mapUri.resolve(mapping.urls[index]) == source) index,
  };
  if (sourceIds.isEmpty) throw const BrowserCheckFailure('Compiler omitted the browser source map');
  final hits = mapLines(mapping, lineOffsets, sourceIds, functions);
  final sourceLines = await File.fromUri(source).readAsLines();
  final functionLine =
      sourceLines.indexWhere((line) => line.startsWith('void downloadFileOnWeb(')) + 1;
  final functionHits = hits[functionLine];
  if (functionHits == null) {
    throw const BrowserCheckFailure('Download function has no mapped entry point');
  }
  if (hits.isEmpty || !hits.values.any((count) => count > 0)) {
    throw const BrowserCheckFailure('Chrome did not execute mapped browser code');
  }
  final lines = hits.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
  await output.writeAsString(
    [
      'SF:lib/src/storage/web_download_helper.dart',
      'FN:$functionLine,downloadFileOnWeb',
      'FNDA:$functionHits,downloadFileOnWeb',
      'FNF:1',
      'FNH:${functionHits > 0 ? 1 : 0}',
      for (final MapEntry(:key, :value) in lines) 'DA:$key,$value',
      'LF:${hits.length}',
      'LH:${hits.values.where((count) => count > 0).length}',
      'end_of_record',
      '',
    ].join('\n'),
  );
  await File('coverage/browser-ranges.json').writeAsString(jsonEncode(functions));
}

typedef CoverageRange = ({int start, int end, int count});

Map<int, int> mapLines(
  SingleMapping mapping,
  List<int> lineOffsets,
  Set<int> sourceIds,
  List<Object?> functions,
) {
  final ranges = coverageRanges(functions);
  final hits = <int, int>{};
  for (final line in mapping.lines) {
    for (final entry in line.entries) {
      final sourceLine = entry.sourceLine;
      if (sourceIds.contains(entry.sourceUrlId) && sourceLine != null) {
        final count = rangeHits(ranges, lineOffsets[line.line] + entry.column);
        final originalLine = sourceLine + 1;
        // Unmapped/non-executable generated text has no V8 function range.
        if (count != null && count > (hits[originalLine] ?? -1)) hits[originalLine] = count;
      }
    }
  }
  return hits;
}

List<CoverageRange> coverageRanges(List<Object?> functions) => [
  for (final function in functions)
    if (function case {'ranges': final List<Object?> ranges})
      for (final range in ranges)
        if (range case {
          'startOffset': final int start,
          'endOffset': final int end,
          'count': final int count,
        })
          (start: start, end: end, count: count),
];

int? rangeHits(List<CoverageRange> ranges, int offset) {
  int? count;
  int? width;
  for (final (:start, :end, count: rangeCount) in ranges) {
    if (start <= offset && offset < end && (width == null || end - start < width)) {
      width = end - start;
      count = rangeCount;
    }
  }
  return count;
}
