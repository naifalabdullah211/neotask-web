import 'package:flutter/material.dart' hide Text;
import 'package:neotask_pro/widgets/localized_text.dart';
import 'package:audioplayers/audioplayers.dart';
import '../theme/app_theme.dart';

/// Inline voice-message playback control shown inside a chat bubble when
/// `ChatMessage.attachmentType == 'voice'`. Plays directly from the
/// Cloudinary URL (streamed, not pre-downloaded) via `audioplayers`,
/// which supports both Web and Android. Voice messages are PERMANENT
/// attachments (no listen-once/delete-after-play behavior) — replayable
/// indefinitely, exactly like an image or file attachment.
class VoiceMessagePlayer extends StatefulWidget {
  const VoiceMessagePlayer({
    super.key,
    required this.url,
    required this.isMine,
  });

  final String url;
  final bool isMine;

  @override
  State<VoiceMessagePlayer> createState() => _VoiceMessagePlayerState();
}

class _VoiceMessagePlayerState extends State<VoiceMessagePlayer> {
  final AudioPlayer _player = AudioPlayer();
  PlayerState _state = PlayerState.stopped;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _player.onPlayerStateChanged.listen((s) {
      if (mounted) setState(() => _state = s);
    });
    _player.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    });
    _player.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    _player.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _state = PlayerState.stopped;
          _position = Duration.zero;
        });
      }
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_state == PlayerState.playing) {
      await _player.pause();
    } else {
      await _player.play(UrlSource(widget.url));
    }
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.toString().padLeft(1, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final iconColor = widget.isMine ? Colors.white : AppColors.deepBlue;
    final trackColor = widget.isMine
        ? Colors.white.withValues(alpha: 0.3)
        : AppColors.deepBlue.withValues(alpha: 0.15);
    final progressColor = widget.isMine ? Colors.white : AppColors.deepBlue;
    final isPlaying = _state == PlayerState.playing;
    final total = _duration.inMilliseconds > 0
        ? _duration
        : const Duration(seconds: 1);
    final progress = (_position.inMilliseconds / total.inMilliseconds).clamp(
      0.0,
      1.0,
    );

    return SizedBox(
      width: 190,
      child: Row(
        children: [
          InkWell(
            onTap: _toggle,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.all(6),
              child: Icon(
                isPlaying
                    ? Icons.pause_circle_filled_rounded
                    : Icons.play_circle_fill_rounded,
                size: 30,
                color: iconColor,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 3,
                    backgroundColor: trackColor,
                    valueColor: AlwaysStoppedAnimation(progressColor),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _duration.inMilliseconds > 0
                      ? '${_formatDuration(_position)} / ${_formatDuration(_duration)}'
                      : 'رسالة صوتية',
                  style: TextStyle(
                    fontSize: 10.5,
                    color: widget.isMine
                        ? Colors.white70
                        : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
