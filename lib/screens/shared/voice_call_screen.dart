import 'dart:async';

import 'package:flutter/material.dart' hide Text;
import 'package:neotask_pro/widgets/localized_text.dart';
import 'package:neotask_pro/l10n/app_i18n.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../models/voice_call_model.dart';
import '../../services/firestore_service.dart';
import '../../services/voice_call_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/user_avatar.dart';

class VoiceCallScreen extends StatefulWidget {
  VoiceCallScreen.outgoing({
    super.key,
    required this.conversationId,
    this.taskId,
    required this.currentUserUid,
    required this.otherUserUid,
    required this.otherUserName,
  })  : callId = VoiceCallService.newCallId(),
        incoming = false;

  const VoiceCallScreen.incoming({
    super.key,
    required this.callId,
    required this.conversationId,
    this.taskId,
    required this.currentUserUid,
    required this.otherUserUid,
    required this.otherUserName,
  }) : incoming = true;

  final String callId;
  final String conversationId;
  final String? taskId;
  final String currentUserUid;
  final String otherUserUid;
  final String otherUserName;
  final bool incoming;

  @override
  State<VoiceCallScreen> createState() => _VoiceCallScreenState();
}

class _VoiceCallScreenState extends State<VoiceCallScreen> {
  static const _peerConfiguration = <String, dynamic>{
    'iceServers': [
      {
        'urls': [
          'stun:stun.l.google.com:19302',
          'stun:stun1.l.google.com:19302',
        ],
      },
    ],
    'sdpSemantics': 'unified-plan',
  };

  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  final Set<String> _seenCandidateIds = <String>{};
  final List<RTCIceCandidate> _pendingRemoteCandidates = [];
  final List<Map<String, dynamic>> _pendingLocalCandidates = [];

  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  StreamSubscription<VoiceCall?>? _callSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _candidateSubscription;
  Timer? _ringTimeout;
  Timer? _durationTicker;

  VoiceCall? _call;
  DateTime? _connectedAt;
  int _elapsedSeconds = 0;
  bool _remoteDescriptionReady = false;
  bool _callDocumentReady = false;
  bool _muted = false;
  bool _finishing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    try {
      await _remoteRenderer.initialize();
      if (!_isActive) return;
      await _openMicrophone();
      if (!_isActive) return;
      await _createPeerConnection();
      if (!_isActive) return;
      if (widget.incoming) {
        await _answerIncomingCall();
      } else {
        await _startOutgoingCall();
      }
      if (!_isActive) return;
      _watchCall();
    } catch (error) {
      if (!_isActive) return;
      setState(() => _error = _friendlyError(error));
      if (widget.incoming || _call != null) {
        await _finalize(VoiceCallStatus.failed, popAfter: false);
      }
    }
  }

  bool get _isActive => mounted && !_finishing;

  Future<void> _openMicrophone() async {
    _localStream = await navigator.mediaDevices.getUserMedia({
      'audio': {
        'echoCancellation': true,
        'noiseSuppression': true,
        'autoGainControl': true,
      },
      'video': false,
    });
  }

  Future<void> _createPeerConnection() async {
    final peer = await createPeerConnection(_peerConfiguration);
    _peerConnection = peer;

    for (final track in _localStream?.getAudioTracks() ?? <MediaStreamTrack>[]) {
      await peer.addTrack(track, _localStream!);
    }

    peer.onIceCandidate = (candidate) {
      final value = candidate.candidate;
      if (value == null || value.isEmpty) return;
      final data = <String, dynamic>{
        'candidate': value,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
      };
      if (!_callDocumentReady) {
        _pendingLocalCandidates.add(data);
        return;
      }
      unawaited(_sendLocalCandidate(data));
    };

    peer.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        _remoteRenderer.srcObject = event.streams.first;
      }
    };

    peer.onConnectionState = (state) {
      final label = state.toString().toLowerCase();
      if (label.endsWith('stateconnected')) {
        _markConnected();
      } else if ((label.contains('failed') || label.contains('closed')) &&
          !_finishing) {
        unawaited(_finalize(VoiceCallStatus.failed));
      }
    };
  }

  Future<void> _startOutgoingCall() async {
    final offer = await _peerConnection!.createOffer({
      'offerToReceiveAudio': true,
      'offerToReceiveVideo': false,
    });
    if (!_isActive) return;
    await _peerConnection!.setLocalDescription(offer);
    if (!_isActive) return;
    final call = VoiceCall(
      callId: widget.callId,
      conversationId: widget.conversationId,
      taskId: widget.taskId,
      callerUid: widget.currentUserUid,
      calleeUid: widget.otherUserUid,
      status: VoiceCallStatus.ringing,
      offer: {'sdp': offer.sdp, 'type': offer.type},
      createdAt: DateTime.now(),
    );
    await VoiceCallService.createCall(call);
    _callDocumentReady = true;
    if (!_isActive) {
      await VoiceCallService.finalizeCall(
        callId: widget.callId,
        status: VoiceCallStatus.cancelled,
        actorUid: widget.currentUserUid,
      );
      return;
    }
    await _flushPendingLocalCandidates();
    if (!mounted) return;
    setState(() => _call = call);
    _watchRemoteCandidates(fromCaller: false);
    _ringTimeout = Timer(const Duration(seconds: 45), () {
      if (_call?.status == VoiceCallStatus.ringing && !_finishing) {
        unawaited(_finalize(VoiceCallStatus.missed));
      }
    });
  }

  Future<void> _answerIncomingCall() async {
    final call = await VoiceCallService.getCall(widget.callId);
    if (!_isActive) return;
    if (call == null || call.status != VoiceCallStatus.ringing) {
      throw StateError('call-not-available');
    }
    _call = call;
    _callDocumentReady = true;
    final offerSdp = call.offer['sdp'] as String?;
    final offerType = call.offer['type'] as String?;
    if (offerSdp == null || offerType == null) {
      throw StateError('invalid-offer');
    }
    await _peerConnection!.setRemoteDescription(
      RTCSessionDescription(offerSdp, offerType),
    );
    if (!_isActive) return;
    _remoteDescriptionReady = true;
    _watchRemoteCandidates(fromCaller: true);

    final answer = await _peerConnection!.createAnswer({
      'offerToReceiveAudio': true,
      'offerToReceiveVideo': false,
    });
    if (!_isActive) return;
    await _peerConnection!.setLocalDescription(answer);
    if (!_isActive) return;
    await VoiceCallService.acceptCall(
      callId: widget.callId,
      answer: {'sdp': answer.sdp, 'type': answer.type},
    );
    _markConnected();
  }

  void _watchCall() {
    _callSubscription = VoiceCallService.watchCall(widget.callId).listen(
      (call) async {
        if (call == null || !mounted) return;
        setState(() => _call = call);

        if (!widget.incoming &&
            call.status == VoiceCallStatus.accepted &&
            !_remoteDescriptionReady) {
          final answer = call.answer;
          final sdp = answer?['sdp'] as String?;
          final type = answer?['type'] as String?;
          if (sdp != null && type != null) {
            await _peerConnection?.setRemoteDescription(
              RTCSessionDescription(sdp, type),
            );
            _remoteDescriptionReady = true;
            await _flushPendingCandidates();
            _markConnected();
          }
        }

        if (call.isTerminal && !_finishing) {
          _finishing = true;
          _ringTimeout?.cancel();
          await _stopMedia();
          if (!mounted) return;
          setState(() {});
          await Future<void>.delayed(const Duration(milliseconds: 900));
          if (mounted) Navigator.of(context).maybePop();
        }
      },
    );
  }

  void _watchRemoteCandidates({required bool fromCaller}) {
    _candidateSubscription = VoiceCallService.watchIceCandidates(
      callId: widget.callId,
      fromCaller: fromCaller,
    ).listen((candidates) async {
      for (final data in candidates) {
        final id = data['id'] as String? ?? '';
        if (id.isEmpty || !_seenCandidateIds.add(id)) continue;
        final candidate = RTCIceCandidate(
          data['candidate'] as String?,
          data['sdpMid'] as String?,
          (data['sdpMLineIndex'] as num?)?.toInt(),
        );
        if (_remoteDescriptionReady) {
          await _peerConnection?.addCandidate(candidate);
        } else {
          _pendingRemoteCandidates.add(candidate);
        }
      }
    });
  }

  Future<void> _flushPendingCandidates() async {
    for (final candidate in _pendingRemoteCandidates) {
      await _peerConnection?.addCandidate(candidate);
    }
    _pendingRemoteCandidates.clear();
  }

  Future<void> _sendLocalCandidate(Map<String, dynamic> candidate) {
    return VoiceCallService.addIceCandidate(
      callId: widget.callId,
      fromCaller: !widget.incoming,
      candidate: candidate,
    );
  }

  Future<void> _flushPendingLocalCandidates() async {
    for (final candidate in _pendingLocalCandidates) {
      await _sendLocalCandidate(candidate);
    }
    _pendingLocalCandidates.clear();
  }

  void _markConnected() {
    if (_connectedAt != null) return;
    _ringTimeout?.cancel();
    _connectedAt = DateTime.now();
    _durationTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _connectedAt == null) return;
      setState(() {
        _elapsedSeconds = DateTime.now().difference(_connectedAt!).inSeconds;
      });
    });
    if (mounted) setState(() {});
  }

  void _toggleMute() {
    final nextMuted = !_muted;
    for (final track in _localStream?.getAudioTracks() ?? <MediaStreamTrack>[]) {
      track.enabled = !nextMuted;
    }
    setState(() => _muted = nextMuted);
  }

  Future<void> _finalize(
    VoiceCallStatus status, {
    bool popAfter = true,
  }) async {
    if (_finishing) return;
    _finishing = true;
    try {
      if (_call != null || widget.incoming) {
        await VoiceCallService.finalizeCall(
          callId: widget.callId,
          status: status,
          actorUid: widget.currentUserUid,
        );
      }
    } finally {
      await _stopMedia();
      if (popAfter && mounted) Navigator.of(context).maybePop();
    }
  }

  Future<void> _stopMedia() async {
    _ringTimeout?.cancel();
    _durationTicker?.cancel();
    await _candidateSubscription?.cancel();
    _candidateSubscription = null;
    for (final track in _localStream?.getTracks() ?? <MediaStreamTrack>[]) {
      track.stop();
    }
    await _localStream?.dispose();
    _localStream = null;
    await _peerConnection?.close();
    _peerConnection = null;
    _remoteRenderer.srcObject = null;
  }

  String _friendlyError(Object error) {
    final value = error.toString().toLowerCase();
    if (value.contains('notallowed') || value.contains('permission')) {
      return 'يلزم السماح باستخدام الميكروفون لإجراء المكالمة';
    }
    if (value.contains('call-not-available')) {
      return 'انتهت المكالمة أو لم تعد متاحة';
    }
    return 'تعذّر بدء المكالمة الصوتية';
  }

  String get _statusLabel {
    if (_error != null) return _error!;
    if (_connectedAt != null) {
      return VoiceCallService.formatDuration(_elapsedSeconds);
    }
    return switch (_call?.status) {
      VoiceCallStatus.declined => 'تم رفض المكالمة',
      VoiceCallStatus.cancelled => 'تم إلغاء المكالمة',
      VoiceCallStatus.missed => 'لم يتم الرد',
      VoiceCallStatus.ended => 'انتهت المكالمة',
      VoiceCallStatus.failed => 'تعذّر الاتصال',
      VoiceCallStatus.accepted => 'جارٍ الاتصال...',
      VoiceCallStatus.ringing || null =>
        widget.incoming ? 'جارٍ توصيل المكالمة...' : 'جارٍ الاتصال...',
    };
  }

  VoiceCallStatus get _hangupStatus {
    if (_connectedAt != null || _call?.status == VoiceCallStatus.accepted) {
      return VoiceCallStatus.ended;
    }
    return widget.incoming
        ? VoiceCallStatus.declined
        : VoiceCallStatus.cancelled;
  }

  @override
  void dispose() {
    _ringTimeout?.cancel();
    _durationTicker?.cancel();
    unawaited(_callSubscription?.cancel());
    unawaited(_candidateSubscription?.cancel());
    for (final track in _localStream?.getTracks() ?? <MediaStreamTrack>[]) {
      track.stop();
    }
    unawaited(_localStream?.dispose());
    unawaited(_peerConnection?.close());
    unawaited(_remoteRenderer.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final otherUser = FirestoreService.getUser(widget.otherUserUid);
    final terminal = _call?.isTerminal ?? false;
    return PopScope(
      canPop: _finishing || terminal || _error != null,
      onPopInvoked: (didPop) {
        if (!didPop) {
          unawaited(_finalize(_hangupStatus));
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF071D3B),
        body: Stack(
          children: [
            Positioned.fill(
              child: Opacity(
                opacity: 0,
                child: IgnorePointer(
                  child: RTCVideoView(_remoteRenderer),
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 28,
                ),
                child: Column(
                  children: [
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: IconButton(
                        tooltip: context.tr('إغلاق'),
                        color: Colors.white70,
                        onPressed: () {
                          unawaited(_finalize(_hangupStatus));
                        },
                        icon: const Icon(Icons.keyboard_arrow_down_rounded),
                      ),
                    ),
                    const Spacer(),
                    UserAvatar(
                      name: widget.otherUserName,
                      imageUrl: otherUser?.profilePhotoUrl,
                      radius: 58,
                      borderColor: AppColors.mintAccent,
                      borderWidth: 3,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      widget.otherUserName,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 27,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _statusLabel,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _error == null
                            ? Colors.white70
                            : const Color(0xFFFF8A8A),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    if (_error != null)
                      FilledButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        child: const Text('إغلاق'),
                      )
                    else
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _RoundCallButton(
                            tooltip: context.tr(
                              _muted ? 'تشغيل الميكروفون' : 'كتم الصوت',
                            ),
                            icon: _muted ? Icons.mic_off : Icons.mic,
                            backgroundColor: Colors.white.withValues(alpha: 0.14),
                            foregroundColor: Colors.white,
                            onPressed: _toggleMute,
                          ),
                          const SizedBox(width: 34),
                          _RoundCallButton(
                            tooltip: context.tr('إنهاء المكالمة'),
                            icon: Icons.call_end_rounded,
                            backgroundColor: const Color(0xFFE5484D),
                            foregroundColor: Colors.white,
                            size: 68,
                            onPressed: () {
                              unawaited(_finalize(_hangupStatus));
                            },
                          ),
                        ],
                      ),
                    const SizedBox(height: 28),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoundCallButton extends StatelessWidget {
  const _RoundCallButton({
    required this.tooltip,
    required this.icon,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.onPressed,
    this.size = 58,
  });

  final String tooltip;
  final IconData icon;
  final Color backgroundColor;
  final Color foregroundColor;
  final VoidCallback onPressed;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: backgroundColor,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(icon, color: foregroundColor, size: size * 0.42),
          ),
        ),
      ),
    );
  }
}
