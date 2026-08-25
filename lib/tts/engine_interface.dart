import 'dart:async';
import 'dart:typed_data';

/// Abstract TTS engine so Piper / Kokoro / Pocket-TTS (or anything else
/// sherpa-onnx supports) are swappable behind one interface.
abstract class TtsEngine {
  /// Loads the model for [voicePackPath]. Must be called before synthesis.
  Future<void> load(String voicePackPath);

  /// Releases native resources.
  Future<void> dispose();

  /// Synthesizes [text] and returns 16-bit mono PCM samples plus the
  /// engine's sample rate.
  Future<SynthesizedAudio> synthesize(String text);

  /// Streaming synthesis: audio chunks arrive before the whole input is
  /// done, so playback can start after the first verse, not the chapter.
  Stream<SynthesizedAudio> synthesizeStream(String text);
}

class SynthesizedAudio {
  final Float32List samples;
  final int sampleRate;

  const SynthesizedAudio({required this.samples, required this.sampleRate});
}
