import 'dart:async';

import 'package:flutter/material.dart' hide Text;
import 'package:neotask_pro/widgets/localized_text.dart';
import 'package:provider/provider.dart';

import '../models/voice_call_model.dart';
import '../providers/auth_provider.dart';
import '../services/biometric_unlock_service.dart';
import '../services/firestore_service.dart';
import '../services/voice_call_service.dart';
import '../theme/app_theme.dart';
import 'user_avatar.dart';
import '../screens/shared/voice_call_screen.dart';

class IncomingCallGate extends StatefulWidget {
  const IncomingCallGate({super.key, required this.child});

  final Widget child;

  @override
  State<IncomingCallGate> createState() => _IncomingCallGateState();
}

class _IncomingCallGateState extends State<IncomingCallGate> {
  // The authenticated listener is inserted/removed as AuthProvider hydrates.
  // A GlobalKey lets Flutter reparent the routed application subtree instead
  // of disposing SplashRouter and accidentally running its startup gates twice.
  final GlobalKey _persistentChildKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final userUid = context.select<AuthProvider, String?>(
      (provider) => provider.currentUser?.uid,
    );
    final persistentChild = KeyedSubtree(
      key: _persistentChildKey,
      child: widget.child,
    );
    if (userUid == null) return persistentChild;
    return _IncomingCallListener(
      key: ValueKey(userUid),
      userUid: userUid,
      child: persistentChild,
    );
  }
}

class _IncomingCallListener extends StatefulWidget {
  const _IncomingCallListener({
    super.key,
    required this.userUid,
    required this.child,
  });

  final String userUid;
  final Widget child;

  @override
  State<_IncomingCallListener> createState() =>
      _IncomingCallListenerState();
}

class _IncomingCallListenerState extends State<_IncomingCallListener> {
  final Set<String> _handledCallIds = <String>{};
  StreamSubscription<List<VoiceCall>>? _subscription;
  List<VoiceCall> _latestCalls = const [];
  bool _dialogOpen = false;
  bool _callScreenOpen = false;

  @override
  void initState() {
    super.initState();
    BiometricUnlockService.applicationLocked.addListener(
      _handleApplicationLockChanged,
    );
    _subscription = VoiceCallService.watchIncomingCalls(widget.userUid).listen(
      (calls) {
        _latestCalls = List<VoiceCall>.unmodifiable(calls);
        unawaited(_handleCalls(_latestCalls));
      },
    );
  }

  void _handleApplicationLockChanged() {
    if (!BiometricUnlockService.applicationLocked.value &&
        _latestCalls.isNotEmpty) {
      unawaited(_handleCalls(_latestCalls));
    }
  }

  Future<void> _handleCalls(List<VoiceCall> calls) async {
    final now = DateTime.now();
    for (final stale in calls.where(
      (call) => now.difference(call.createdAt) > const Duration(seconds: 45),
    )) {
      if (_handledCallIds.add(stale.callId)) {
        unawaited(
          VoiceCallService.finalizeCall(
            callId: stale.callId,
            status: VoiceCallStatus.missed,
            actorUid: widget.userUid,
          ),
        );
      }
    }

    if (!mounted ||
        BiometricUnlockService.applicationLocked.value ||
        _dialogOpen ||
        _callScreenOpen) {
      return;
    }
    final fresh = calls.where(
      (call) =>
          now.difference(call.createdAt) <= const Duration(seconds: 45) &&
          !_handledCallIds.contains(call.callId),
    );
    if (fresh.isEmpty) return;
    final call = fresh.first;
    _dialogOpen = true;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      if (BiometricUnlockService.applicationLocked.value) {
        _dialogOpen = false;
        return;
      }
      _handledCallIds.add(call.callId);
      final accepted = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _IncomingCallDialog(
          call: call,
          currentUserUid: widget.userUid,
        ),
      );
      _dialogOpen = false;
      if (!mounted || accepted != true) return;

      final current = await VoiceCallService.getCall(call.callId);
      if (!mounted || current?.status != VoiceCallStatus.ringing) return;
      final caller = FirestoreService.getUser(call.callerUid);
      _callScreenOpen = true;
      await Navigator.of(context).push(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => VoiceCallScreen.incoming(
            callId: call.callId,
            conversationId: call.conversationId,
            taskId: call.taskId,
            currentUserUid: widget.userUid,
            otherUserUid: call.callerUid,
            otherUserName: caller?.name ?? 'مستخدم NeoTask',
          ),
        ),
      );
      _callScreenOpen = false;
    });
  }

  @override
  void dispose() {
    BiometricUnlockService.applicationLocked.removeListener(
      _handleApplicationLockChanged,
    );
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _IncomingCallDialog extends StatefulWidget {
  const _IncomingCallDialog({
    required this.call,
    required this.currentUserUid,
  });

  final VoiceCall call;
  final String currentUserUid;

  @override
  State<_IncomingCallDialog> createState() => _IncomingCallDialogState();
}

class _IncomingCallDialogState extends State<_IncomingCallDialog> {
  StreamSubscription<VoiceCall?>? _subscription;
  bool _responding = false;

  @override
  void initState() {
    super.initState();
    _subscription = VoiceCallService.watchCall(widget.call.callId).listen(
      (call) {
        if (!mounted || call == null || call.status == VoiceCallStatus.ringing) {
          return;
        }
        Navigator.of(context).pop(false);
      },
    );
  }

  Future<void> _accept() async {
    if (_responding) return;
    setState(() => _responding = true);
    final current = await VoiceCallService.getCall(widget.call.callId);
    if (!mounted) return;
    Navigator.of(context).pop(current?.status == VoiceCallStatus.ringing);
  }

  Future<void> _decline() async {
    if (_responding) return;
    setState(() => _responding = true);
    await VoiceCallService.finalizeCall(
      callId: widget.call.callId,
      status: VoiceCallStatus.declined,
      actorUid: widget.currentUserUid,
    );
    if (mounted) Navigator.of(context).pop(false);
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final caller = FirestoreService.getUser(widget.call.callerUid);
    final callerName = caller?.name ?? 'مستخدم NeoTask';
    return PopScope(
      canPop: false,
      child: AlertDialog(
        backgroundColor: const Color(0xFF071D3B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              UserAvatar(
                name: callerName,
                imageUrl: caller?.profilePhotoUrl,
                radius: 45,
                borderColor: AppColors.mintAccent,
                borderWidth: 2.5,
              ),
              const SizedBox(height: 18),
              Text(
                callerName,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'مكالمة صوتية واردة',
                style: TextStyle(color: Colors.white70, fontSize: 15),
              ),
              const SizedBox(height: 28),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _DialogCallAction(
                    label: 'رفض',
                    icon: Icons.call_end_rounded,
                    color: const Color(0xFFE5484D),
                    onPressed: _responding ? null : _decline,
                  ),
                  _DialogCallAction(
                    label: 'رد',
                    icon: Icons.call_rounded,
                    color: AppColors.mintAccent,
                    onPressed: _responding ? null : _accept,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DialogCallAction extends StatelessWidget {
  const _DialogCallAction({
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: color,
          shape: const CircleBorder(),
          child: InkWell(
            onTap: onPressed,
            customBorder: const CircleBorder(),
            child: SizedBox(
              width: 60,
              height: 60,
              child: Icon(icon, color: Colors.white, size: 28),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.white70)),
      ],
    );
  }
}
