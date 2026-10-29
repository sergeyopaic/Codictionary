import 'dart:convert';

import '../../domain/entities/dictionary_snapshot.dart';
import '../../domain/entities/vocabulary.dart';
import '../../domain/entities/word_entity.dart';
import '../../domain/exceptions/backup_exceptions.dart';
import '../../domain/services/backup_codec.dart';

/// Backup format, version 1:
///
/// ```json
/// {
///   "format": "codictionary-backup",
///   "version": 1,
///   "createdAt": "2026-10-29T12:00:00.000Z",
///   "words": [{"id", "source", "target", "shortExplanation"?,
///              "longExplanation"?, "createdAt"}],        // manual order
///   "vocabularies": [{"id", "name", "description", "icon", "wordIds"}]
/// }
/// ```
///
/// Independent of the on-disk storage format, so storage can change without
/// breaking old backups. [decode] rejects anything it cannot restore
/// exactly instead of guessing.
class JsonBackupCodec implements BackupCodec {
  const JsonBackupCodec();

  static const format = 'codictionary-backup';
  static const version = 1;

  @override
  String encode(DictionarySnapshot snapshot) =>
      const JsonEncoder.withIndent('  ').convert({
        'format': format,
        'version': version,
        'createdAt': snapshot.createdAt.toUtc().toIso8601String(),
        'words': [
          for (final w in snapshot.words)
            {
              'id': w.id,
              'source': w.source,
              'target': w.target,
              if (w.shortExplanation != null)
                'shortExplanation': w.shortExplanation,
              if (w.longExplanation != null)
                'longExplanation': w.longExplanation,
              'createdAt': w.createdAt.toUtc().toIso8601String(),
            },
        ],
        'vocabularies': [
          for (final v in snapshot.vocabularies)
            {
              'id': v.id,
              'name': v.name,
              'description': v.description,
              'icon': v.iconPath,
              'wordIds': v.wordIds,
            },
        ],
      });

  @override
  DictionarySnapshot decode(String text) {
    final Object? json;
    try {
      json = jsonDecode(text);
    } on FormatException {
      throw const BackupFormatException(
        'The text is not valid JSON. Copy the whole backup and try again.',
      );
    }
    if (json is! Map || json['format'] != format) {
      throw const BackupFormatException('This is not a Codictionary backup.');
    }
    final v = json['version'];
    if (v is! int || v < 1) {
      throw const BackupFormatException('The backup has no valid version.');
    }
    if (v > version) {
      throw BackupFormatException(
        'This backup was made by a newer version of Codictionary '
        '(format $v). Update the app to restore it.',
      );
    }

    final words = <WordEntity>[];
    final wordIds = <String>{};
    final sources = <String>{};
    for (final (i, item) in _list(json, 'words').indexed) {
      final where = 'word ${i + 1}';
      final m = _map(item, where);
      final id = _requiredString(m, 'id', where);
      final source = _requiredString(m, 'source', where);
      if (!wordIds.add(id)) {
        throw BackupFormatException('Duplicate word id "$id".');
      }
      if (!sources.add(source.trim().toLowerCase())) {
        throw BackupFormatException('"$source" appears twice.');
      }
      words.add(
        WordEntity(
          id: id,
          source: source,
          target: _string(m, 'target', where),
          shortExplanation: _optionalString(m, 'shortExplanation', where),
          longExplanation: _optionalString(m, 'longExplanation', where),
          createdAt: _date(m, 'createdAt', where),
        ),
      );
    }

    final vocabularies = <Vocabulary>[];
    final vocabularyIds = <String>{};
    for (final (i, item) in _list(json, 'vocabularies').indexed) {
      final where = 'vocabulary ${i + 1}';
      final m = _map(item, where);
      final id = _requiredString(m, 'id', where);
      if (!vocabularyIds.add(id)) {
        throw BackupFormatException('Duplicate vocabulary id "$id".');
      }
      final members = m['wordIds'];
      if (members is! List || members.any((e) => e is! String)) {
        throw BackupFormatException('$where: "wordIds" must be a list of ids.');
      }
      final memberIds = List<String>.from(members);
      if (memberIds.toSet().length != memberIds.length) {
        throw BackupFormatException('$where lists a word twice.');
      }
      final unknown = memberIds.where((id) => !wordIds.contains(id));
      if (unknown.isNotEmpty) {
        throw BackupFormatException(
          '$where refers to a word that is not in the backup '
          '("${unknown.first}").',
        );
      }
      vocabularies.add(
        Vocabulary(
          id: id,
          name: _string(m, 'name', where),
          description: _string(m, 'description', where),
          iconPath: _string(m, 'icon', where),
          wordIds: memberIds,
        ),
      );
    }

    return DictionarySnapshot(
      words: words,
      vocabularies: vocabularies,
      createdAt: _date(json, 'createdAt', 'the backup'),
    );
  }

  static List<Object?> _list(Map<dynamic, dynamic> m, String key) {
    final v = m[key];
    if (v is! List) throw BackupFormatException('"$key" is missing.');
    return v;
  }

  static Map<dynamic, dynamic> _map(Object? v, String where) {
    if (v is! Map) throw BackupFormatException('$where is not an object.');
    return v;
  }

  static String _string(Map<dynamic, dynamic> m, String key, String where) {
    final v = m[key];
    if (v is! String) throw BackupFormatException('$where: "$key" is missing.');
    return v;
  }

  static String _requiredString(
    Map<dynamic, dynamic> m,
    String key,
    String where,
  ) {
    final v = _string(m, key, where);
    if (v.trim().isEmpty) {
      throw BackupFormatException('$where: "$key" is empty.');
    }
    return v;
  }

  static String? _optionalString(
    Map<dynamic, dynamic> m,
    String key,
    String where,
  ) {
    final v = m[key];
    if (v == null || v is String) return v as String?;
    throw BackupFormatException('$where: "$key" must be text.');
  }

  static DateTime _date(Map<dynamic, dynamic> m, String key, String where) {
    final v = m[key];
    final parsed = v is String ? DateTime.tryParse(v) : null;
    if (parsed == null) {
      throw BackupFormatException('$where: "$key" is not a date.');
    }
    return parsed;
  }
}
