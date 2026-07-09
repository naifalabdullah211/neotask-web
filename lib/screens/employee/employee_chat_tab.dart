import 'package:flutter/material.dart';
import '../../models/message_model.dart';
import '../../services/firestore_service.dart';
import '../shared/chat_thread_screen.dart';

/// Employee's general (task-independent) chat with the manager. Since there
/// is only ever one manager account (single-manager architecture), this tab
/// goes straight to the conversation body — no conversation-list step is
/// needed on the employee side (unlike the manager side, which has multiple
/// employees to choose from).
class EmployeeChatTab extends StatelessWidget {
  const EmployeeChatTab({super.key, required this.employeeUid});

  final String employeeUid;

  @override
  Widget build(BuildContext context) {
    final manager = FirestoreService.getManager();
    if (manager == null) {
      return const Center(child: Text('لا يوجد مدير مسجّل حاليًا'));
    }
    return ChatThreadBody(
      conversationId: ChatMessage.generalConversationId(employeeUid),
      currentUserUid: employeeUid,
      otherUserUid: manager.uid,
    );
  }
}
