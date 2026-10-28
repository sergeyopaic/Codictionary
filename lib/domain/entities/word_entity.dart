/// A dictionary entry. This is the single source of truth for a word across
/// the domain, data and presentation layers.
class WordEntity {
  final String id;

  /// The English word or phrase.
  final String source;

  /// The Russian translation.
  final String target;

  /// Short AI explanation, or null if none has been generated.
  final String? shortExplanation;

  /// Detailed AI explanation, or null if none has been generated.
  final String? longExplanation;

  /// When the word was first added. Never changes on update.
  final DateTime createdAt;

  const WordEntity({
    required this.id,
    required this.source,
    required this.target,
    this.shortExplanation,
    this.longExplanation,
    required this.createdAt,
  });

  bool get hasShortExplanation =>
      shortExplanation != null && shortExplanation!.trim().isNotEmpty;

  bool get hasLongExplanation =>
      longExplanation != null && longExplanation!.trim().isNotEmpty;

  /// Returns a copy with the given fields replaced. Pass null explicitly to
  /// clear an explanation. [id] and [createdAt] are immutable.
  WordEntity copyWith({
    String? source,
    String? target,
    Object? shortExplanation = _unset,
    Object? longExplanation = _unset,
  }) {
    return WordEntity(
      id: id,
      source: source ?? this.source,
      target: target ?? this.target,
      shortExplanation: identical(shortExplanation, _unset)
          ? this.shortExplanation
          : shortExplanation as String?,
      longExplanation: identical(longExplanation, _unset)
          ? this.longExplanation
          : longExplanation as String?,
      createdAt: createdAt,
    );
  }

  /// Same word with a different id; used when repairing duplicate ids.
  WordEntity withId(String newId) => WordEntity(
    id: newId,
    source: source,
    target: target,
    shortExplanation: shortExplanation,
    longExplanation: longExplanation,
    createdAt: createdAt,
  );

  @override
  bool operator ==(Object other) =>
      other is WordEntity &&
      other.id == id &&
      other.source == source &&
      other.target == target &&
      other.shortExplanation == shortExplanation &&
      other.longExplanation == longExplanation &&
      // Same moment regardless of time zone (storage keeps UTC).
      other.createdAt.isAtSameMomentAs(createdAt);

  @override
  int get hashCode => Object.hash(
    id,
    source,
    target,
    shortExplanation,
    longExplanation,
    createdAt.microsecondsSinceEpoch,
  );

  @override
  String toString() => 'WordEntity($id, $source → $target)';
}

const Object _unset = Object();
