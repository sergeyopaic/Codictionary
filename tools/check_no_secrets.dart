// Fails if API keys could ship: real-looking keys in the given files or
// folders, or a bundled .env with non-empty *_KEY values.
//
// Usage: dart tools/check_no_secrets.dart [--tracked] <file-or-dir> [...]
// CI runs it on the git-tracked files and on the release build (build/web),
// whose assets include the .env that flutter_dotenv loads.
//
// Findings name the file and line but never print the secret itself.
import 'dart:io';

final _patterns = <String, RegExp>{
  'OpenAI API key': RegExp(r'sk-[A-Za-z0-9_\-]{20,}'),
  'DeepL Free API key': RegExp(
    r'[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}:fx',
  ),
};

final _envKeyWithValue = RegExp(r'^\s*([A-Z0-9_]*KEY)\s*=\s*(\S+)');

const _textExtensions = {
  '.dart',
  '.js',
  '.mjs',
  '.json',
  '.html',
  '.txt',
  '.md',
  '.yaml',
  '.yml',
  '.env',
  '.xml',
  '.plist',
  '.gradle',
  '.kts',
  '.properties',
  '.xcconfig',
  '.cc',
  '.cpp',
  '.h',
  '.swift',
  '.kt',
  '.sh',
  '.ps1',
  '.bat',
};

bool _isText(String path) {
  final name = path.split(RegExp(r'[\\/]')).last;
  if (name == '.env' || name.startsWith('.env.')) return true;
  final dot = name.lastIndexOf('.');
  return dot >= 0 && _textExtensions.contains(name.substring(dot));
}

bool _isEnv(String path) {
  final name = path.split(RegExp(r'[\\/]')).last;
  return name == '.env' || name.startsWith('.env.');
}

Iterable<File> _files(String target) sync* {
  final type = FileSystemEntity.typeSync(target);
  if (type == FileSystemEntityType.file) {
    yield File(target);
  } else if (type == FileSystemEntityType.directory) {
    for (final e in Directory(target).listSync(recursive: true)) {
      if (e is File) yield e;
    }
  } else {
    stderr.writeln('warning: $target does not exist, skipped');
  }
}

/// `--tracked` stands for every file git tracks (too many for a command line).
List<String> _expand(List<String> args) => [
  for (final a in args)
    if (a == '--tracked') ..._gitTracked() else a,
];

List<String> _gitTracked() {
  final r = Process.runSync('git', ['ls-files', '-z']);
  if (r.exitCode != 0) {
    stderr.writeln('git ls-files failed: ${r.stderr}');
    exit(2);
  }
  return (r.stdout as String).split('\x00').where((p) => p.isNotEmpty).toList();
}

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln(
      'usage: dart tools/check_no_secrets.dart [--tracked] <path> [...]',
    );
    exit(64);
  }
  final findings = <String>[];
  var scanned = 0;
  for (final target in _expand(args)) {
    for (final file in _files(target)) {
      if (!_isText(file.path)) continue;
      final List<String> lines;
      try {
        lines = file.readAsLinesSync();
      } on FileSystemException {
        continue; // binary or unreadable despite the extension
      }
      scanned++;
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        for (final entry in _patterns.entries) {
          if (entry.value.hasMatch(line)) {
            findings.add('${file.path}:${i + 1}: ${entry.key}');
          }
        }
        if (_isEnv(file.path)) {
          final m = _envKeyWithValue.firstMatch(line);
          if (m != null) {
            findings.add(
              '${file.path}:${i + 1}: ${m.group(1)} has a value '
              '(${m.group(2)!.length} characters)',
            );
          }
        }
      }
    }
  }
  if (findings.isEmpty) {
    stdout.writeln('No secrets found ($scanned text files checked).');
    return;
  }
  stderr.writeln('Possible secrets found (values not shown):');
  findings.forEach(stderr.writeln);
  exit(1);
}
