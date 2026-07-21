import 'dart:async';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';
import '../theme/app_theme.dart';
import '../utils/audio_bytes_reader.dart';

/// Press-and-hold voice message recorder button. Sits in the chat input
/// bar alongside the paperclip (attach) button (see ChatThreadBody). On
/// release, calls [onRecorded] with the recorded audio bytes + a
/// generated filename; the caller is responsible for uploading (via the
/// EXISTING CloudinaryService, exactly like image/file attachments) and
/// sending the message with `attachmentType: 'voice'`.
///
/// PLATFORM NOTE: `record` package supports both Web (MediaRecorder) and
/// Android (AudioRecord) without platform-specific code here — encoding
/// is forced to AAC-LC in an M4A container on all platforms for
/// consistent playback via `audioplayers`.
class VoiceMessageRecorderButton extends StatefulWidget {
  const VoiceMessageRecorderButton({
    super.key,
    required this.onRecorded,
    this.enabled = true,
  });

  /// Called with (audioBytes, filename, durationSeconds) once recording
  /// stops via release (not on cancel/too-short).
  final void Function(List<int> bytes, String filename, int durationSeconds)
  onRecorded;

  final bool enabled;

  @override
  State<VoiceMessageRecorderButton> createState() =>
      _VoiceMessageRecorderButtonState();
}

class _VoiceMessageRecorderButtonState
    extends State<VoiceMessageRecorderButton> {
  final AudioRecorder _recorder = AudioRecorder();
  bool _isRecording = false;
  DateTime? _startedAt;
  Timer? _tickTimer;
  int _elapsedSeconds = 0;

  // Minimum viable recording — guards against an accidental tap producing
  // a near-zero-length, useless voice message.
  static const _minDurationSeconds = 1;

  @override
  void dispose() {
    _tickTimer?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  Future<bool> _ensureMicPermission() async {
    // `permission_handler` is a no-op-safe pass-through on Web (browser
    // handles its own getUserMedia prompt), so this call is safe on both
    // platforms without branching.
    final status = await Permission.microphone.request();
    return status.isGranted || status.isLimited;
  }

  Future<void> _startRecording() async {
    if (!widget.enabled || _isRecording) return;
    final granted = await _ensureMicPermission();
    if (!granted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('يلزم إذن الميكروفون لتسجيل رسالة صوتية'),
          ),
        );
      }
      return;
    }

    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) return;

    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc),
      path: 'voice_message', // ignored on Web; required non-null on IO
    );

    setState(() {
      _isRecording = true;
      _startedAt = DateTime.now();
      _elapsedSeconds = 0;
    });

    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _elapsedSeconds = DateTime.now().difference(_startedAt!).inSeconds;
      });
    });
  }

  Future<void> _stopRecording({required bool cancelled}) async {
    if (!_isRecording) return;
    _tickTimer?.cancel();
    _tickTimer = null;

    final path = await _recorder.stop();
    final duration = _startedAt != null
        ? DateTime.now().difference(_startedAt!).inSeconds
        : 0;

    setState(() {
      _isRecording = false;
      _startedAt = null;
      _elapsedSeconds = 0;
    });

    if (cancelled || path == null || duration < _minDurationSeconds) {
      return;
    }

    try {
      final bytes = await readAudioBytes(path);
      if (bytes.isEmpty) return;
      final filename = 'voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      widget.onRecorded(bytes, filename, duration);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذّر قراءة التسجيل الصوتي: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isRecording) {
      return _RecordingIndicator(
        elapsedSeconds: _elapsedSeconds,
        onCancel: () => _stopRecording(cancelled: true),
        onStop: () => _stopRecording(cancelled: false),
      );
    }

    // BUGFIX #1 (previous attempt): IconButton(tooltip: ...) internally
    // installs its OWN long-press gesture recognizer to show its Tooltip,
    // which won the gesture arena against the outer GestureDetector's
    // onLongPressStart — the tooltip text appeared but _startRecording()
    // was never called. Fixed by removing IconButton.
    //
    // BUGFIX #2 (root cause of "ما تضغط ابدا" persisting after fix #1):
    // GestureDetector's default `behavior` is HitTestBehavior.deferToChild
    // — it ONLY registers a gesture where the CHILD itself is opaque to
    // hit-testing. A plain Container with no `color`/`decoration` paints
    // nothing (no RenderDecoratedBox), so it is NOT a valid hit target;
    // only the tiny area where the Icon's glyph itself renders would ever
    // register a hit (unreliably, especially on the Web canvas renderer).
    // With IconButton removed, the GestureDetector had NO reliable hit
    // target left at all, so long-press did nothing whatsoever. Fixed by
    // setting `behavior: HitTestBehavior.opaque`, which makes the ENTIRE
    // 40x40 box a valid long-press target regardless of what is painted
    // inside it.
    return Opacity(
      opacity: widget.enabled ? 1.0 : 0.4,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onLongPressStart: widget.enabled ? (_) => _startRecording() : null,
        onLongPressEnd: widget.enabled
            ? (_) => _stopRecording(cancelled: false)
            : null,
        onLongPressCancel: widget.enabled
            ? () => _stopRecording(cancelled: true)
            : null,
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          child: const Icon(
            Icons.mic_none_rounded,
            color: AppColors.textSecondary,
            size: 22,
          ),
        ),
      ),
    );
  }
}

/// Small recording-in-progress pill shown in place of the mic button
/// while actively recording — shows elapsed time + cancel/stop controls.
class _RecordingIndicator extends StatelessWidget {
  const _RecordingIndicator({
    required this.elapsedSeconds,
    required this.onCancel,
    required this.onStop,
  });

  final int elapsedSeconds;
  final VoidCallback onCancel;
  final VoidCallback onStop;

  String get _label {
    final m = (elapsedSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (elapsedSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.statusRejected.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.fiber_manual_record,
            size: 12,
            color: AppColors.statusRejected,
          ),
          const SizedBox(width: 6),
          Text(
            _label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.statusRejected,
            ),
          ),
          const SizedBox(width: 6),
          InkWell(
            onTap: onCancel,
            child: const Icon(
              Icons.close_rounded,
              size: 18,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 4),
          InkWell(
            onTap: onStop,
            child: const Icon(
              Icons.stop_circle_rounded,
              size: 22,
              color: AppColors.deepBlue,
            ),
          ),
        ],
      ),
    );
  }
}
