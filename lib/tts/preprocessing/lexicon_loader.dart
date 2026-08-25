import 'package:flutter/services.dart' show rootBundle;

import 'pronunciation_lexicon.dart';

/// Flutter-asset loading for the lexicon (kept separate so the lexicon
/// itself stays pure Dart and unit-testable without the Flutter SDK).
Future<PronunciationLexicon> loadLexiconFromAsset([
  String assetPath = 'assets/lexicon/biblical_names.tsv',
]) async {
  return PronunciationLexicon.parse(await rootBundle.loadString(assetPath));
}
