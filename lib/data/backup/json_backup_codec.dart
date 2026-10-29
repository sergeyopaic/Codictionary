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
      throw const BackupFormatException(BackupProblem.notJson);
    }
    if (json is! Map || json['format'] != format) {
      throw const BackupFormatException(BackupProblem.notBackup);
    }
    final v = json['version'];
    if (v is! int || v < 1) {
      throw const BackupFormatException(BackupProblem.noVersion);
    }
    if (v > version) {
      throw BackupFormatException(BackupProblem.newerVersion, value: '$v');
    }

    final words = <WordEntity>[];
    final wordIds = <String>{};
    final sources = <String>{};
    for (final (i, item) in _list(json, 'words').indexed) {
      final at = _At('word', i + 1);
      final m = _map(item, at);
      final id = _requiredString(m, 'id', at);
      final source = _requiredString(m, 'source', at);
      if (!wordIds.add(id)) {
        throw BackupFormatException(BackupProblem.duplicateWordId, value: id);
      }
      if (!sources.add(source.trim().toLowerCase())) {
        throw BackupFormatException(BackupProblem.duplicateWord, value: source);
      }
      words.add(
        WordEntity(
          id: id,
          source: source,
          target: _string(m, 'target', at),
          shortExplanation: _optionalString(m, 'shortExplanation', at),
          longExplanation: _optionalString(m, 'longExplanation', at),
          createdAt: _date(m, 'createdAt', at),
        ),
      );
    }

    final vocabularies = <Vocabulary>[];
    final vocabularyIds = <String>{};
    for (final (i, item) in _list(json, 'vocabularies').indexed) {
      final at = _At('vocabulary', i + 1);
      final m = _map(item, at);
      final id = _requiredString(m, 'id', at);
      if (!vocabularyIds.add(id)) {
        throw BackupFormatException(
          BackupProblem.duplicateVocabularyId,
          value: id,
        );
      }
      final members = m['wordIds'];
      if (members is! List || members.any((e) => e is! String)) {
        throw at.error(BackupProblem.membersNotList);
      }
      final memberIds = List<String>.from(members);
      if (memberIds.toSet().length != memberIds.length) {
        throw at.error(BackupProblem.memberTwice);
      }
      final unknown = memberIds.where((id) => !wordIds.contains(id));
      if (unknown.isNotEmpty) {
        throw at.error(BackupProblem.unknownMember, value: unknown.first);
      }
      vocabularies.add(
        Vocabulary(
          id: id,
          name: _string(m, 'name', at),
          description: _string(m, 'description', at),
          iconPath: _string(m, 'icon', at),
          wordIds: memberIds,
        ),
      );
    }

    return DictionarySnapshot(
      words: words,
      vocabularies: vocabularies,
      createdAt: _date(json, 'createdAt', const _At('backup', null)),
    );
  }

  static List<Object?> _list(Map<dynamic, dynamic> m, String key) {
    final v = m[key];
    if (v is! List) {
      throw BackupFormatException(BackupProblem.missingList, field: key);
    }
    return v;
  }

  static Map<dynamic, dynamic> _map(Object? v, _At at) {
    if (v is! Map) throw at.error(BackupProblem.notObject);
    return v;
  }

  static String _string(Map<dynamic, dynamic> m, String key, _At at) {
    final v = m[key];
    if (v is! String) throw at.error(BackupProblem.missingField, field: key);
    return v;
  }

  static String _requiredString(Map<dynamic, dynamic> m, String key, _At at) {
    final v = _string(m, key, at);
    if (v.trim().isEmpty) throw at.error(BackupProblem.emptyField, field: key);
    return v;
  }

  static String? _optionalString(Map<dynamic, dynamic> m, String key, _At at) {
    final v = m[key];
    if (v == null || v is String) return v as String?;
    throw at.error(BackupProblem.notText, field: key);
  }

  static DateTime _date(Map<dynamic, dynamic> m, String key, _At at) {
    final v = m[key];
    final parsed = v is String ? DateTime.tryParse(v) : null;
    if (parsed == null) throw at.error(BackupProblem.notDate, field: key);
    return parsed;
  }
}

/// Where in the backup a problem is (for the error message).
class _At {
  const _At(this.item, this.index);
  final String item;
  final int? index;

  BackupFormatException error(
    BackupProblem problem, {
    String? field,
    String? value,
  }) => BackupFormatException(
    problem,
    item: item,
    index: index,
    field: field,
    value: value,
  );
}
