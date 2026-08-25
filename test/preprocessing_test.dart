import 'package:test/test.dart';
import 'package:open_scripture_voice/tts/preprocessing/pronunciation_lexicon.dart';
import 'package:open_scripture_voice/tts/preprocessing/text_normalizer.dart';

void main() {
  group('TextNormalizer', () {
    final n = TextNormalizer();

    test('rejects empty text', () {
      expect(n.process('   '), isNull);
    });

    test('collapses whitespace and normalizes quotes/dashes', () {
      expect(
        n.normalizePunctuationAndWhitespace('  “God  said” —\nlet  there… '),
        '"God said", let there...',
      );
    });

    test('expands numbers to spoken form', () {
      expect(n.expandNumbers('Psalm 23'), 'Psalm twenty-three');
      expect(n.expandNumbers('in 1448 BC'), 'in one thousand four hundred forty-eight BC');
      expect(n.expandNumbers('1000'), 'one thousand');
      expect(n.expandNumbers('7'), 'seven');
    });

    test('full pipeline', () {
      expect(n.process('John 3:16  —  “For God…”'),
          'John three:sixteen, "For God..."');
    });
  });

  group('PronunciationLexicon', () {
    test('parses TSV, skips comments and blanks', () {
      final lex = PronunciationLexicon.parse(
          '# comment\n\nNebuchadnezzar\tneb-yoo-kad-NEZ-er\nHabakkuk\thə-BAK-uk\n');
      expect(lex.length, 2);
    });

    test('applies whole-word, case-insensitive replacement', () {
      final lex = PronunciationLexicon.parse(
          'Nebuchadnezzar\tneb-yoo-kad-NEZ-er\nCapernaum\tkə-PUR-nay-əm\n');
      expect(
        lex.apply('King NEBUCHADNEZZAR went to Capernaum.'),
        'King neb-yoo-kad-NEZ-er went to kə-PUR-nay-əm.',
      );
      // Whole-word only: must not rewrite inside other words.
      expect(lex.apply('Nebuchadnezzarsson'), 'Nebuchadnezzarsson');
    });

    test('empty lexicon is a no-op', () {
      final lex = PronunciationLexicon.parse('');
      expect(lex.apply('Habakkuk'), 'Habakkuk');
    });
  });
}
