/// Text preprocessing pipeline, run once per verse and cached:
///   1. validate raw verse text
///   2. normalize punctuation and whitespace
///   3. expand numbers into spoken form
///   4. apply the biblical-name pronunciation lexicon (handled by
///      pronunciation_lexicon.dart, applied after this step)
///
/// Bump [pipelineVersion] whenever any step changes so cached
/// `normalized_text` values are regenerated.
class TextNormalizer {
  static const int pipelineVersion = 1;

  /// Returns null if the raw text is unusable.
  String? validate(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return null;
    return t;
  }

  String normalizePunctuationAndWhitespace(String text) {
    var t = text;
    // Curly quotes/dashes to plain forms engines handle consistently.
    t = t
        .replaceAll('\u2018', "'")
        .replaceAll('\u2019', "'")
        .replaceAll('\u201C', '"')
        .replaceAll('\u201D', '"')
        .replaceAll('\u2026', '...'); // ellipsis
    // Dashes become a spoken pause; absorb surrounding spaces.
    t = t.replaceAll(RegExp(r'\s*[\u2013\u2014]\s*'), ', ');
    // Collapse whitespace.
    t = t.replaceAll(RegExp(r'\s+'), ' ').trim();
    return t;
  }

  String expandNumbers(String text) {
    return text.replaceAllMapped(RegExp(r'\b\d+\b'), (m) {
      final n = int.tryParse(m.group(0)!);
      if (n == null) return m.group(0)!;
      return numberToWords(n);
    });
  }

  /// Full pipeline for one verse. Returns null for invalid input.
  String? process(String raw) {
    final valid = validate(raw);
    if (valid == null) return null;
    return expandNumbers(normalizePunctuationAndWhitespace(valid));
  }

  static const _ones = [
    'zero', 'one', 'two', 'three', 'four', 'five', 'six', 'seven', 'eight',
    'nine', 'ten', 'eleven', 'twelve', 'thirteen', 'fourteen', 'fifteen',
    'sixteen', 'seventeen', 'eighteen', 'nineteen',
  ];
  static const _tens = [
    '', '', 'twenty', 'thirty', 'forty', 'fifty', 'sixty', 'seventy',
    'eighty', 'ninety',
  ];

  static String numberToWords(int n) {
    if (n < 0) return 'minus ${numberToWords(-n)}';
    if (n < 20) return _ones[n];
    if (n < 100) {
      final t = _tens[n ~/ 10];
      final r = n % 10;
      return r == 0 ? t : '$t-${_ones[r]}';
    }
    if (n < 1000) {
      final h = '${_ones[n ~/ 100]} hundred';
      final r = n % 100;
      return r == 0 ? h : '$h ${numberToWords(r)}';
    }
    if (n < 1000000) {
      final th = '${numberToWords(n ~/ 1000)} thousand';
      final r = n % 1000;
      return r == 0 ? th : '$th ${numberToWords(r)}';
    }
    final m = '${numberToWords(n ~/ 1000000)} million';
    final r = n % 1000000;
    return r == 0 ? m : '$m ${numberToWords(r)}';
  }
}
