import 'dart:async';
import 'package:flutter/material.dart' hide Text;
import 'package:neotask_pro/widgets/localized_text.dart';
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
///
/// GESTURE DESIGN (rewritten — see history below): uses `onTapDown` /
/// `onTapUp` / `onTapCancel` (immediate on touch, NOT a timed long-press)
/// so recording starts the instant the finger/pointer touches the button
/// — exactly like WhatsApp/Telegram voice notes — with an immediate
/// visual color-change on touch-down as feedback, independent of whether
/// the permission/record start succeeds or fails.
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
  bool _isStarting = false;
  bool _pressedDown = false;
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

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.statusRejected,
      ),
    );
  }

  Future<bool> _ensureMicPermission() async {
    // `permission_handler` is a no-op-safe pass-through on Web (browser
    // handles its own getUserMedia prompt), so this call is safe on both
    // platforms without branching.
    final status = await Permission.microphone.request();
    return status.isGranted || status.isLimited;
  }

  Future<void> _handleTapDown() async {
    // Immediate visual feedback the INSTANT the finger touches the
    // button — independent of permission checks / recorder startup,
    // which are asynchronous and may take a moment (or fail silently
    // without this).
    setState(() {
      _pressedDown = true;
    });

    if (!widget.enabled || _isRecording || _isStarting) return;
    _isStarting = true;
    try {
      final granted = await _ensureMicPermission();
      if (!granted) {
        _showError(
          'يلزم إذن الميكروفون لتسجيل رسالة صوتية. '
          'يرجى السماح للمتصفح بالوصول إلى الميكروفون من إعدادات الموقع.',
        );
        return;
      }

      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) {
        _showError('تعذّر الوصول إلى الميكروفون (رفض الإذن).');
        return;
      }

      await _recorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: 'voice_message', // ignored on Web; required non-null on IO
      );

      if (!mounted) return;
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
    } catch (e) {
      // CRITICAL: without this catch, any exception thrown by the
      // permission APIs or `_recorder.start()` (e.g. browser blocking
      // microphone access, unsupported codec, insecure context, etc.)
      // was previously swallowed SILENTLY by Flutter's async gesture
      // callback error handling — the user would see absolutely nothing,
      // which is indistinguishable from "the button doesn't respond at
      // all". Surfacing it here is required for any real diagnosis.
      _showError('تعذّر بدء التسجيل: $e');
    } finally {
      _isStarting = false;
    }
  }

  Future<void> _stopRecording({required bool cancelled}) async {
    if (mounted) {
      setState(() {
        _pressedDown = false;
      });
    }
    if (!_isRecording) return;
    _tickTimer?.cancel();
    _tickTimer = null;

    String? path;
    try {
      path = await _recorder.stop();
    } catch (e) {
      _showError('تعذّر إيقاف التسجيل: $e');
    }

    final duration = _startedAt != null
        ? DateTime.now().difference(_startedAt!).inSeconds
        : 0;

    if (mounted) {
      setState(() {
        _isRecording = false;
        _startedAt = null;
        _elapsedSeconds = 0;
      });
    }

    if (cancelled || path == null || duration < _minDurationSeconds) {
      return;
    }

    try {
      final bytes = await readAudioBytes(path);
      if (bytes.isEmpty) {
        _showError('التسجيل الصوتي فارغ — حاول مرة أخرى.');
        return;
      }
      final filename = 'voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      widget.onRecorded(bytes, filename, duration);
    } catch (e) {
      _showError('تعذّر قراءة التسجيل الصوتي: $e');
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

    // HISTORY OF FIXES for this button (kept for context — see also the
    // debugging notes accompanying this feature):
    // 1) IconButton(tooltip:...) inside a GestureDetector — IconButton's
    //    OWN internal long-press recognizer (for its Tooltip) won the
    //    gesture arena, so the outer onLongPressStart never fired.
    // 2) Replaced IconButton with a plain Icon+Container, but
    //    GestureDetector's default `behavior` (deferToChild) meant the
    //    non-opaque Container was not a valid hit target at all — still
    //    nothing fired.
    // 3) (Current) Switched from onLongPress* (timed, ~500ms delay, zero
    //    feedback before firing) to onTapDown/onTapUp/onTapCancel
    //    (instant on touch — matches WhatsApp/Telegram voice notes),
    //    added `behavior: HitTestBehavior.opaque` so the whole box is a
    //    valid hit target, added instant color-change visual feedback on
    //    touch-down (independent of async permission/recorder result),
    //    and wrapped the async start logic in try/catch with SnackBar
    //    error reporting so ANY failure is visible instead of silent.
    return Opacity(
      opacity: widget.enabled ? 1.0 : 0.4,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: widget.enabled ? (_) => _handleTapDown() : null,
        onTapUp: widget.enabled
            ? (_) => _stopRecording(cancelled: false)
            : null,
        onTapCancel: widget.enabled
            ? () => _stopRecording(cancelled: true)
            : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _pressedDown
                ? AppColors.deepBlue.withValues(alpha: 0.12)
                : Colors.transparent,
          ),
          child: Icon(
            Icons.mic_none_rounded,
            color: _pressedDown ? AppColors.deepBlue : AppColors.textSecondary,
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
