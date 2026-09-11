import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

import 'engine_interface.dart';

/// Thrown for any engine/voice-pack failure. Callers should catch this and
/// surface a friendly message instead of crashing.
class TtsException implements Exception {
  final String message;
  final Object? cause;
  const TtsException(this.message, [this.cause]);

  @override
  String toString() =>
      'TtsException: $message${cause != null ? ' ($cause)' : ''}';
}

/// sherpa_onnx-backed TtsEngine.
///
/// Handles Piper, Kokoro, and VITS-family models — the only difference is
/// which config object is populated. Voice pack directories are expected to
/// contain the model file plus its companion files (tokens, espeak-ng-data,
/// voices.bin for Kokoro, etc.).
class SherpaEngine implements TtsEngine {
  sherpa.OfflineTts? _tts;
  int _sampleRate = 22050;

  /// Speaker id for multi-speaker models. For Kokoro this selects the voice
  /// (e.g. 0-based index of voices.bin entries — `am_adam` is the male
  /// "Adam" voice); for single-speaker Piper voices it stays 0.
  int speakerId;

  SherpaEngine({this.speakerId = 0});

  bool get isLoaded => _tts != null;

  @override
  Future<void> load(String voicePackPath) async {
    // Never leave a half-loaded engine behind on failure.
    await dispose();
    try {
      final dir = Directory(voicePackPath);
      if (!dir.existsSync()) {
        throw TtsException('Voice pack not found at $voicePackPath');
      }

      final files = dir
          .listSync()
          .whereType<File>()
          .map((f) => f.uri.pathSegments.last)
          .toList();

      final modelFile = files.firstWhere(
        (f) => f.endsWith('.onnx'),
        orElse: () =>
            throw TtsException('No .onnx model in voice pack $voicePackPath'),
      );
      final modelPath = '$voicePackPath/$modelFile';
      final tokensPath = '$voicePackPath/tokens.txt';
      if (!File(tokensPath).existsSync()) {
        throw TtsException('Voice pack is missing tokens.txt');
      }

      // Detect engine family from pack contents. Kokoro packs ship
      // voices.bin and a model named kokoro-*; Piper/VITS packs ship
      // espeak-ng-data.
      final isKokoro = modelFile.contains('kokoro');
      final espeakDataDir = '$voicePackPath/espeak-ng-data';

      final sherpa.OfflineTtsConfig config;
      if (isKokoro) {
        if (!File('$voicePackPath/voices.bin').existsSync()) {
          throw TtsException('Kokoro voice pack is missing voices.bin');
        }
        config = sherpa.OfflineTtsConfig(
          // OfflineTtsModelConfig has no `tokens` param in 1.13.x — the
          // tokens path lives on the per-engine config (kokoro/vits).
          model: sherpa.OfflineTtsModelConfig(
            kokoro: sherpa.OfflineTtsKokoroModelConfig(
              model: modelPath,
              voices: '$voicePackPath/voices.bin',
              tokens: tokensPath,
              dataDir: espeakDataDir,
            ),
            numThreads: 2,
            debug: false,
            provider: 'cpu',
          ),
          // Upstream typo in sherpa_onnx's Dart API ("Senetences") — the
          // field really is named like this in 1.13.x; the correct spelling
          // does not compile.
          maxNumSenetences: 1,
        );
      } else {
        // Piper / VITS-family.
        if (!Directory(espeakDataDir).existsSync()) {
          throw TtsException(
              'Piper voice pack is missing espeak-ng-data/ directory');
        }
        config = sherpa.OfflineTtsConfig(
          model: sherpa.OfflineTtsModelConfig(
            vits: sherpa.OfflineTtsVitsModelConfig(
              model: modelPath,
              tokens: tokensPath,
              dataDir: espeakDataDir,
            ),
            numThreads: 2,
            debug: false,
            provider: 'cpu',
          ),
          // Upstream typo, see the Kokoro branch above.
          maxNumSenetences: 1,
        );
      }

      _tts = sherpa.OfflineTts(config);
      _sampleRate = _tts!.sampleRate;
    } on TtsException {
      rethrow;
    } catch (e) {
      // Native/ONNX init failures surface as arbitrary errors — normalize.
      throw TtsException('Failed to initialize TTS engine', e);
    }
  }

  @override
  Future<SynthesizedAudio> synthesize(String text) async {
    final tts = _tts;
    if (tts == null) {
      throw const TtsException(
          'TTS engine is not loaded — install or select a voice first');
    }
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return SynthesizedAudio(samples: Float32List(0), sampleRate: _sampleRate);
    }
    try {
      final audio = tts.generate(text: trimmed, sid: speakerId, speed: 1.0);
      if (audio.samples.isEmpty) {
        throw const TtsException('Engine returned empty audio');
      }
      return SynthesizedAudio(samples: audio.samples, sampleRate: _sampleRate);
    } on TtsException {
      rethrow;
    } catch (e) {
      throw TtsException('Synthesis failed', e);
    }
  }

  @override
  Stream<SynthesizedAudio> synthesizeStream(String text) async* {
    // sherpa_onnx's callback-based incremental generation is exposed on the
    // native side; at the plugin level the practical pattern is to split the
    // input into sentences and yield each as it completes, which is what the
    // verse-by-verse pipeline in cache_manager already does. This stream is
    // the per-call equivalent for long single inputs.
    final sentences = _splitSentences(text);
    for (final s in sentences) {
      if (s.trim().isEmpty) continue;
      yield await synthesize(s);
    }
  }

  List<String> _splitSentences(String text) {
    final parts = text.split(RegExp(r'(?<=[.!?])\s+'));
    return parts.where((p) => p.trim().isNotEmpty).toList();
  }

  @override
  Future<void> dispose() async {
    try {
      _tts?.free();
    } catch (_) {
      // Native teardown errors are not actionable.
    }
    _tts = null;
  }
}
