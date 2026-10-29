/// Persistence record for a collection (the JSON shape on disk).
///
/// Records written before collections had ids and members contain only
/// `name`, `description` and `icon`; they read with an empty [id] (assigned
/// and persisted by `VocabularyRepositoryImpl`) and no members.
class VocabularyRecord {
  const VocabularyRecord({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    this.wordIds = const [],
  });

  final String id;
  final String name;
  final String description;
  final String icon;

  /// Member word ids in the order they were added.
  final List<String> wordIds;

  /// Throws [FormatException] for a malformed member list, so damaged data is
  /// reported instead of silently dropping members.
  factory VocabularyRecord.fromMap(Map<dynamic, dynamic> m) {
    final rawIds = m['wordIds'];
    final List<String> wordIds;
    if (rawIds == null) {
      wordIds = const [];
    } else if (rawIds is List && rawIds.every((e) => e is String)) {
      wordIds = List<String>.from(rawIds);
    } else {
      throw const FormatException('wordIds must be a list of strings');
    }
    final id = m['id'];
    return VocabularyRecord(
      id: id is String ? id : '',
      name: (m['name'] ?? '').toString(),
      description: (m['description'] ?? '').toString(),
      icon: (m['icon'] ?? '').toString(),
      wordIds: wordIds,
    );
  }

  Map<String, Object> toMap() => {
    'id': id,
    'name': name,
    'description': description,
    'icon': icon,
    'wordIds': wordIds,
  };
}
