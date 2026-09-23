import 'dart:convert';
import 'dart:io';

import 'package:source_maps/source_maps.dart';

/// Map Chrome's measured ranges through the compiler's original Dart locations.
Future<void> writeDartCoverage(File javascript, List<Object?> functions, File output) async {
  final mapping = parse(await File('${javascript.path}.map').readAsString()) as SingleMapping;
  final text = await javascript.readAsString();
  final lineOffsets = [0, ...RegExp('\n').allMatches(text).map((match) => match.end)];
  final source = File('lib/src/storage/web_download_helper.dart').absolute.uri;
  final mapUri = File('${javascript.path}.map').absolute.uri;
  final sourceIds = <int>{
    for (var index = 0; index < mapping.urls.length; index++)
      if (mapUri.resolve(mapping.urls[index]) == source) index,
  };
  if (sourceIds.isEmpty) throw StateError('Compiler omitted the browser source map');
  final hits = mapLines(mapping, lineOffsets, sourceIds, functions);
  final sourceLines = await File.fromUri(source).readAsLines();
  final functionLine =
      sourceLines.indexWhere((line) => line.startsWith('void downloadFileOnWeb(')) + 1;
  final functionHits = hits[functionLine];
  if (functionHits == null) throw StateError('Download function has no mapped entry point');
  if (hits.isEmpty || !hits.values.any((count) => count > 0)) {
    throw StateError('Chrome did not execute mapped browser code');
  }
  final lines = hits.keys.toList()..sort();
  await output.writeAsString(
    [
      'SF:lib/src/storage/web_download_helper.dart',
      'FN:$functionLine,downloadFileOnWeb',
      'FNDA:$functionHits,downloadFileOnWeb',
      'FNF:1',
      'FNH:${functionHits > 0 ? 1 : 0}',
      for (final line in lines) 'DA:$line,${hits[line]}',
      'LF:${hits.length}',
      'LH:${hits.values.where((count) => count > 0).length}',
      'end_of_record',
      '',
    ].join('\n'),
  );
  await File('coverage/browser-ranges.json').writeAsString(jsonEncode(functions));
}

Map<int, int> mapLines(
  SingleMapping mapping,
  List<int> lineOffsets,
  Set<int> sourceIds,
  List<Object?> functions,
) {
  final hits = <int, int>{};
  for (final line in mapping.lines) {
    for (final entry in line.entries) {
      if (!sourceIds.contains(entry.sourceUrlId) || entry.sourceLine == null) continue;
      final offset = lineOffsets[line.line] + entry.column;
      final count = rangeHits(functions, offset);
      // Unmapped/non-executable generated text has no V8 function range.
      if (count == null) continue;
      final originalLine = entry.sourceLine! + 1;
      if (count > (hits[originalLine] ?? -1)) hits[originalLine] = count;
    }
  }
  return hits;
}

int? rangeHits(List<Object?> functions, int offset) {
  int? count;
  int? width;
  for (final function in functions.cast<Map<String, Object?>>()) {
    for (final range in (function['ranges']! as List<Object?>).cast<Map<String, Object?>>()) {
      final start = range['startOffset']! as int;
      final end = range['endOffset']! as int;
      if (start <= offset && offset < end && (width == null || end - start < width)) {
        width = end - start;
        count = range['count']! as int;
      }
    }
  }
  return count;
}
