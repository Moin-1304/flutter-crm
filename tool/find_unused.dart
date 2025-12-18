import 'dart:collection';
import 'dart:convert';
import 'dart:io';

/// Simple unused Dart file detector for the lib/ directory.
///
/// Strategy:
/// - Build a graph of file -> referenced files via import/export/part directives.
/// - Start from lib/main.dart as the entry-point and traverse to mark reachable files.
/// - Anything under lib/ not reachable is reported as unused.
/// - Optionally move unused files into lib/_unused/ preserving relative structure.
///
/// Notes:
/// - Only considers static imports/exports/parts. Dynamic imports or reflection are ignored.
/// - Treats `package:<pkg>/...` as local, using pubspec `name` for <pkg>.
/// - Ignores non-local packages and `dart:` imports.
/// - Respects existing `_unused` directory by skipping it from scanning.
Future<void> main(List<String> args) async {
  final repoRoot = Directory.current.absolute;
  final libDir = Directory(pathJoin(repoRoot.path, 'lib'));
  if (!await libDir.exists()) {
    stderr.writeln('lib/ directory not found at: ${libDir.path}');
    exitCode = 2;
    return;
  }

  final packageName = await _readPackageName(pathJoin(repoRoot.path, 'pubspec.yaml'));
  final entryFile = File(pathJoin(libDir.path, 'main.dart')).absolute;
  if (!await entryFile.exists()) {
    stderr.writeln('Entry file lib/main.dart not found.');
    exitCode = 2;
    return;
  }

  final allDartFiles = await _listDartFiles(libDir);
  // Build adjacency list
  final edges = <String, Set<String>>{}; // from -> {to}
  for (final filePath in allDartFiles) {
    edges[filePath] = await _parseReferences(filePath, packageName, libDir.path, allDartFiles);
  }

  // Reachability from entry
  final reachable = _bfsReachable(entryFile.path, edges);
  final unused = allDartFiles.difference(reachable);

  // Filter out generated part files that might be referenced via `part of` name only (edge-less)
  // Keep .g.dart files if their corresponding library exists and references them via `part`.
  // Our parser already adds edges for `part` directives, so nothing else to do here.

  final sortedUnused = unused.toList()..sort();

  final shouldMove = args.contains('--move') || args.contains('--apply');
  if (sortedUnused.isEmpty) {
    stdout.writeln('No unused files detected.');
    return;
  }

  stdout.writeln('Unused Dart files (${sortedUnused.length}):');
  for (final f in sortedUnused) {
    stdout.writeln(' - ${_relativeTo(f, libDir.path)}');
  }

  if (!shouldMove) {
    stdout.writeln('\nDry run. Pass --move to relocate them under lib/_unused/.');
    return;
  }

  final unusedDir = Directory(pathJoin(libDir.path, '_unused'));
  if (!await unusedDir.exists()) {
    await unusedDir.create(recursive: true);
  }

  for (final absPath in sortedUnused) {
    final relFromLib = _relativeTo(absPath, libDir.path);
    final targetPath = pathJoin(unusedDir.path, relFromLib);
    final targetDir = Directory(File(targetPath).parent.path);
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }
    final src = File(absPath);
    if (await src.exists()) {
      await src.rename(targetPath);
      stdout.writeln('Moved: lib/$relFromLib -> lib/_unused/$relFromLib');
    }
  }
}

Future<String> _readPackageName(String pubspecPath) async {
  try {
    final content = await File(pubspecPath).readAsString();
    final lines = const LineSplitter().convert(content);
    for (final raw in lines) {
      final line = raw.trim();
      if (line.startsWith('name:')) {
        final name = line.substring('name:'.length).trim();
        // stop at comment if present
        final hash = name.indexOf('#');
        return (hash >= 0 ? name.substring(0, hash) : name).trim();
      }
    }
  } catch (_) {}
  return '';
}

Future<Set<String>> _listDartFiles(Directory libDir) async {
  final result = <String>{};
  await for (final entity in libDir.list(recursive: true, followLinks: false)) {
    final path = entity.path;
    if (entity is File && path.endsWith('.dart')) {
      // Skip anything under lib/_unused already
      if (path.contains('${Platform.pathSeparator}_unused${Platform.pathSeparator}')) continue;
      result.add(File(path).absolute.path);
    }
  }
  return result;
}

Future<Set<String>> _parseReferences(
  String filePath,
  String packageName,
  String libRootPath,
  Set<String> knownFiles,
) async {
  final refs = <String>{};
  final file = File(filePath);
  String content;
  try {
    content = await file.readAsString();
  } catch (_) {
    return refs;
  }

  final directive = RegExp(r"^\s*(import|export|part)\s+['\]([^'\]+)['\]", multiLine: true);
  for (final match in directive.allMatches(content)) {
    final kind = match.group(1) ?? '';
    final spec = match.group(2) ?? '';
    final resolved = _resolveSpec(filePath, spec, packageName, libRootPath);
    if (resolved == null) continue;
    if (knownFiles.contains(resolved)) {
      refs.add(resolved);
    }
    // If it's a `part` directive but the target isn't present, ignore silently
  }
  return refs;
}

String? _resolveSpec(String fromFile, String spec, String packageName, String libRootPath) {
  if (spec.startsWith('dart:')) return null; // SDK imports are out of scope
  if (spec.startsWith('package:')) {
    if (packageName.isEmpty) return null;
    final prefix = 'package:$packageName/';
    if (!spec.startsWith(prefix)) return null; // other packages
    final rel = spec.substring(prefix.length);
    return _resolveAgainst(pathJoin(libRootPath, ''), rel);
  }
  if (spec.startsWith('asset:')) return null;
  // Relative path import/export/part
  return _resolveAgainst(File(fromFile).parent.path, spec);
}

Set<String> _bfsReachable(String start, Map<String, Set<String>> edges) {
  final visited = <String>{};
  final queue = Queue<String>()..add(start);
  while (queue.isNotEmpty) {
    final node = queue.removeFirst();
    if (!visited.add(node)) continue;
    final neighbors = edges[node] ?? const <String>{};
    for (final n in neighbors) {
      if (!visited.contains(n)) queue.add(n);
    }
  }
  return visited;
}

String _relativeTo(String absPath, String baseDir) {
  final baseUri = Directory(baseDir).absolute.uri;
  final fileUri = File(absPath).absolute.uri;
  final relUri = fileUri.replace(path: fileUri.path.replaceFirst(baseUri.path, ''));
  var rel = relUri.path;
  if (rel.startsWith('/')) rel = rel.substring(1);
  return rel;
}

String _resolveAgainst(String baseDir, String relative) {
  final base = Directory(baseDir).absolute.uri;
  final resolved = base.resolve(relative);
  return File(resolved.toFilePath()).absolute.path;
}

String pathJoin(String a, String b) {
  if (a.endsWith(Platform.pathSeparator)) return a + b;
  return a + Platform.pathSeparator + b;
}

