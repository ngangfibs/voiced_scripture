import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

/// Background/lock-screen audio handler wrapping just_audio.
///
/// Plays a gapless queue of per-verse WAV files. Verses are appended to the
/// queue as synthesis completes, so playback starts after the first verse.
class ScriptureAudioHandler extends BaseAudioHandler
    with QueueHandler, SeekHandler {
  final AudioPlayer player = AudioPlayer();
  final ConcatenatingAudioSource playlist =
      ConcatenatingAudioSource(children: []);

  ScriptureAudioHandler() {
    player.setAudioSource(playlist);
    player.playbackEventStream.listen(_broadcastState);
  }

  /// Appends one finished verse to the queue (called as synthesis lands).
  Future<void> enqueueVerse({
    required String filePath,
    required String title,
    required int verse,
  }) async {
    final source = AudioSource.uri(
      Uri.file(filePath),
      tag: MediaItem(id: filePath, title: title, album: 'Open Scripture Voice'),
    );
    await playlist.add(source);
  }

  Future<void> clearQueue() async {
    await player.stop();
    await playlist.clear();
  }

  /// Playback speed is a player setting (pitch-corrected rate), never a
  /// re-synthesis — one cached file serves every speed.
  Future<void> setSpeed(double speed) => player.setSpeed(speed);

  @override
  Future<void> play() => player.play();

  @override
  Future<void> pause() => player.pause();

  @override
  Future<void> stop() async {
    await player.stop();
    await super.stop();
  }

  @override
  Future<void> seek(Duration position) => player.seek(position);

  @override
  Future<void> skipToNext() => player.seekToNext();

  @override
  Future<void> skipToPrevious() => player.seekToPrevious();

  void _broadcastState(PlaybackEvent event) {
    playbackState.add(playbackState.value.copyWith(
      controls: const [
        MediaControl.skipToPrevious,
        MediaControl.play,
        MediaControl.pause,
        MediaControl.skipToNext,
        MediaControl.stop,
      ],
      playing: player.playing,
      processingState: {
            ProcessingState.idle: AudioProcessingState.idle,
            ProcessingState.loading: AudioProcessingState.loading,
            ProcessingState.buffering: AudioProcessingState.buffering,
            ProcessingState.ready: AudioProcessingState.ready,
            ProcessingState.completed: AudioProcessingState.completed,
          }[player.processingState] ??
          // Map lookup is nullable; copyWith requires a non-null state.
          AudioProcessingState.idle,
      updatePosition: player.position,
      bufferedPosition: player.bufferedPosition,
      speed: player.speed,
      queueIndex: event.currentIndex,
    ));
  }
}
