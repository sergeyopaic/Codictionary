import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Layer rules (see ARCHITECTURE.MD):
///   presentation → domain ← data, and only composition wires data in.
void main() {
  final files = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .map((f) => f.path.replaceAll('\\', '/'))
      .toList();

  /// Imports of [file] as normalized `lib/...` paths or `package:` URIs.
  List<String> importsOf(String file) {
    final dir = Uri.file(file).resolve('.');
    final result = <String>[];
    final pattern = RegExp(r"""^\s*(?:import|export)\s+'([^']+)'""");
    for (final line in File(file).readAsLinesSync()) {
      final target = pattern.firstMatch(line)?.group(1);
      if (target == null) continue;
      if (target.startsWith('package:codictionary/')) {
        result.add('lib/${target.substring('package:codictionary/'.length)}');
      } else if (target.contains(':')) {
        result.add(target);
      } else {
        final path = dir.resolve(target).toFilePath(windows: false);
        result.add(path.substring(path.indexOf('lib/')));
      }
    }
    return result;
  }

  void expectNoImports(
    String layer,
    bool Function(String import) forbidden,
    String reason,
  ) {
    final violations = [
      for (final f in files.where((f) => f.startsWith('lib/$layer/')))
        for (final i in importsOf(f))
          if (forbidden(i)) '$f → $i',
    ];
    expect(violations, isEmpty, reason: reason);
  }

  test('domain depends on nothing else in the app or on Flutter', () {
    expectNoImports(
      'domain',
      (i) =>
          i.startsWith('lib/presentation/') ||
          i.startsWith('lib/data/') ||
          i.startsWith('lib/composition/') ||
          i.startsWith('package:flutter/'),
      'the domain layer must stay independent',
    );
  });

  test('presentation uses domain contracts, never data or wiring', () {
    expectNoImports(
      'presentation',
      (i) =>
          i.startsWith('lib/data/') ||
          i.startsWith('lib/composition/') ||
          i.startsWith('package:http/') ||
          i.startsWith('package:path_provider/') ||
          i.startsWith('package:flutter_dotenv/') ||
          i.startsWith('package:get_it/'),
      'UI must not reach storage or API clients directly',
    );
  });

  test('data does not depend on presentation or wiring', () {
    expectNoImports(
      'data',
      (i) =>
          i.startsWith('lib/presentation/') || i.startsWith('lib/composition/'),
      'data implements domain contracts only',
    );
  });

  test('no global service locator remains', () {
    final uses = [
      for (final f in files)
        for (final i in importsOf(f))
          if (i.startsWith('package:get_it/')) '$f → $i',
    ];
    expect(uses, isEmpty);
  });
}
