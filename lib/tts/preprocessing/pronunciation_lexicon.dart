/// Biblical-name pronunciation lexicon.
///
/// Loaded from assets/lexicon/biblical_names.tsv and applied to verse text
/// BEFORE phonemization, so the respelling reaches the engine's phonemizer
/// (espeak-ng for Piper, misaki for Kokoro) instead of the original word.
/// Both engines also support user-supplied lexicon overrides natively; this
/// file is the single source of truth and can additionally be copied into a
/// voice pack's data dir for engine-level loading.
class PronunciationLexicon {
  final Map<String, String> _entries;

  PronunciationLexicon._(this._entries);

  int get length => _entries.length;

  /// Parses TSV lines: `Name<TAB>respelling`. Blank lines and `#` comments
  /// are ignored.
  static PronunciationLexicon parse(String tsv) {
    final entries = <String, String>{};
    for (final line in tsv.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
      final parts = trimmed.split('\t');
      if (parts.length < 2) continue;
      entries[parts[0].trim().toLowerCase()] = parts[1].trim();
    }
    return PronunciationLexicon._(entries);
  }

  /// Replaces whole-word, case-insensitive occurrences of each name with its
  /// respelling.
  String apply(String text) {
    if (_entries.isEmpty) return text;
    var out = text;
    _entries.forEach((name, respelling) {
      out = out.replaceAllMapped(
        RegExp('\\b${RegExp.escape(name)}\\b', caseSensitive: false),
        (_) => respelling,
      );
    });
    return out;
  }
}
