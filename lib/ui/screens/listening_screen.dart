import 'dart:async';

import 'package:flutter/material.dart';

import '../../player/playback_controller.dart';
import '../../service_locator.dart';

/// Listening screen: transport controls, speed, bookmark, sleep timer,
/// plus the "synthesizing…" indicator shown on a cache miss.
class ListeningScreen extends StatefulWidget {
  final int bookId;
  final String bookName;
  final int chapter;

  const ListeningScreen({
    super.key,
    required this.bookId,
    required this.bookName,
    required this.chapter,
  });

  @override
  State<ListeningScreen> createState() => _ListeningScreenState();
}

class _ListeningScreenState extends State<ListeningScreen> {
  PlaybackController get _controller => Services.playback;
  double _speed = 1.0;
  StreamSubscription<String>? _errorSub;

  @override
  void initState() {
    super.initState();
    _errorSub = _controller.errors.listen((message) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
    });
    _controller.playChapter(
      bookId: widget.bookId,
      chapter: widget.chapter,
      voiceId: Services.activeVoiceId,
      bookName: widget.bookName,
    );
  }

  @override
  void dispose() {
    _errorSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final audio = _controller.audio;
    return Scaffold(
      appBar: AppBar(title: Text('${widget.bookName} ${widget.chapter}')),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          StreamBuilder<bool>(
            stream: _controller.synthesizing,
            initialData: false,
            builder: (context, snap) => snap.data == true
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2)),
                        SizedBox(width: 12),
                        Text('Synthesizing…'),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          const Spacer(),
          StreamBuilder<Duration>(
            stream: audio.player.positionStream,
            builder: (context, snap) {
              final pos = snap.data ?? Duration.zero;
              final total = audio.player.duration ?? Duration.zero;
              return Column(
                children: [
                  Slider(
                    value: pos.inMilliseconds
                        .clamp(0, total.inMilliseconds)
                        .toDouble(),
                    max: total.inMilliseconds.toDouble().clamp(1, 1 << 62),
                    onChanged: (v) =>
                        audio.seek(Duration(milliseconds: v.round())),
                  ),
                  Text(
                    '${_fmt(pos)} / ${_fmt(total)}',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ],
              );
            },
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                iconSize: 40,
                icon: const Icon(Icons.skip_previous),
                onPressed: audio.skipToPrevious,
              ),
              StreamBuilder<bool>(
                stream: audio.player.playingStream,
                builder: (context, snap) => IconButton(
                  iconSize: 64,
                  icon: Icon(snap.data == true
                      ? Icons.pause_circle
                      : Icons.play_circle),
                  onPressed: () =>
                      snap.data == true ? audio.pause() : audio.play(),
                ),
              ),
              IconButton(
                iconSize: 40,
                icon: const Icon(Icons.skip_next),
                onPressed: audio.skipToNext,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            alignment: WrapAlignment.center,
            children: [
              // Speed is a player setting — never re-synthesizes.
              DropdownButton<double>(
                value: _speed,
                items: const [
                  DropdownMenuItem(value: 0.75, child: Text('0.75×')),
                  DropdownMenuItem(value: 1.0, child: Text('1×')),
                  DropdownMenuItem(value: 1.25, child: Text('1.25×')),
                  DropdownMenuItem(value: 1.5, child: Text('1.5×')),
                  DropdownMenuItem(value: 2.0, child: Text('2×')),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => _speed = v);
                  _controller.setSpeed(v);
                },
              ),
              IconButton(
                icon: const Icon(Icons.bookmark_add),
                tooltip: 'Bookmark',
                onPressed: _addBookmark,
              ),
              IconButton(
                icon: const Icon(Icons.bedtime),
                tooltip: 'Sleep timer',
                onPressed: _pickSleepTimer,
              ),
            ],
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '${d.inHours > 0 ? '${d.inHours}:' : ''}$m:$s';
  }

  Future<void> _addBookmark() async {
    final pos = _controller.audio.player.position;
    await Services.addBookmark(
      bookId: widget.bookId,
      chapter: widget.chapter,
      positionMs: pos.inMilliseconds,
    );
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Bookmark saved')));
    }
  }

  void _pickSleepTimer() {
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final mins in [15, 30, 45, 60])
            ListTile(
              title: Text('$mins minutes'),
              onTap: () {
                _controller.setSleepTimer(mins);
                Navigator.pop(sheetContext);
              },
            ),
          ListTile(
            title: const Text('Off'),
            onTap: () {
              _controller.setSleepTimer(null);
              Navigator.pop(sheetContext);
            },
          ),
        ],
      ),
    );
  }
}
