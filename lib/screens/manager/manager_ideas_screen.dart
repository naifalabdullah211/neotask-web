import 'package:flutter/material.dart' hide Text;
import 'package:neotask_pro/widgets/localized_text.dart';
import 'package:neotask_pro/l10n/app_i18n.dart';
import 'package:intl/intl.dart' as intl;

import '../../models/manager_idea_model.dart';
import '../../models/user_model.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';

class ManagerIdeasScreen extends StatefulWidget {
  const ManagerIdeasScreen({
    super.key,
    required this.manager,
    this.readOnly = false,
  });

  final AppUser manager;
  final bool readOnly;

  @override
  State<ManagerIdeasScreen> createState() => _ManagerIdeasScreenState();
}

class _ManagerIdeasScreenState extends State<ManagerIdeasScreen> {
  final _controller = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final content = _controller.text.trim();
    if (content.length < 3 || _saving) return;

    setState(() => _saving = true);
    try {
      await FirestoreService.addManagerIdea(
        content: content,
        manager: widget.manager,
      );
      _controller.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حفظ الفكرة')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر حفظ الفكرة، حاول مرة أخرى')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete(ManagerIdea idea) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف الفكرة؟'),
        content: const Text('سيتم حذفها نهائيًا من قائمة أفكار المدير'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await FirestoreService.deleteManagerIdea(idea.ideaId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        title: const Text('أفكار المدير'),
        backgroundColor: const Color(0xFF071D3B),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<ManagerIdea>>(
        stream: FirestoreService.watchManagerIdeas(),
        builder: (context, snapshot) {
          return LayoutBuilder(
            builder: (context, constraints) {
              final horizontal = constraints.maxWidth >= 720 ? 28.0 : 14.0;
              return ListView(
                padding: EdgeInsets.fromLTRB(horizontal, 20, horizontal, 32),
                children: [
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 900),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const _IdeasIntro(),
                          if (!widget.readOnly) ...[
                            const SizedBox(height: 16),
                            _IdeaComposer(
                              controller: _controller,
                              saving: _saving,
                              onSubmit: _submit,
                            ),
                          ],
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              const Text(
                                'الأفكار المسجلة',
                                style: TextStyle(
                                  color: Color(0xFF102A4C),
                                  fontSize: 19,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(width: 9),
                              _CountBadge(count: snapshot.data?.length ?? 0),
                            ],
                          ),
                          const SizedBox(height: 10),
                          if (snapshot.connectionState ==
                                  ConnectionState.waiting &&
                              !snapshot.hasData)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.all(36),
                                child: CircularProgressIndicator(),
                              ),
                            )
                          else if (snapshot.hasError)
                            const _IdeasMessage(
                              icon: Icons.cloud_off_outlined,
                              message: 'تعذر تحميل الأفكار الآن',
                            )
                          else if ((snapshot.data ?? const <ManagerIdea>[])
                              .isEmpty)
                            const _IdeasMessage(
                              icon: Icons.lightbulb_outline,
                              message: 'لا توجد أفكار مسجلة حتى الآن',
                            )
                          else
                            for (final idea in snapshot.data!)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _IdeaCard(
                                  idea: idea,
                                  canDelete: !widget.readOnly,
                                  onDelete: () => _delete(idea),
                                ),
                              ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _IdeasIntro extends StatelessWidget {
  const _IdeasIntro();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF071D3B),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF071D3B).withValues(alpha: 0.15),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFFE6AD36).withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(
              Icons.lightbulb_outline,
              color: Color(0xFFE6AD36),
              size: 30,
            ),
          ),
          const SizedBox(width: 15),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'مساحة أفكار المدير',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'سجّل أي تطوير أو ملاحظة لتبقى محفوظة للمراجعة والتنفيذ',
                  style: TextStyle(color: Color(0xFFB9C7D9), height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _IdeaComposer extends StatelessWidget {
  const _IdeaComposer({
    required this.controller,
    required this.saving,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final bool saving;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDCE4EE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'اكتب فكرتك',
            style: TextStyle(
              color: Color(0xFF102A4C),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: controller,
            minLines: 3,
            maxLines: 6,
            maxLength: 1000,
            decoration: InputDecoration(
              hintText: context.tr('مثال: إضافة تقرير مختصر للمهام المتأخرة...'),
              filled: true,
              fillColor: const Color(0xFFF7F9FC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(13),
                borderSide: const BorderSide(color: Color(0xFFDCE4EE)),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: saving ? null : onSubmit,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.navy,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 14,
                ),
              ),
              icon: saving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.add_comment_outlined),
              label: Text(saving ? 'جارٍ الحفظ' : 'حفظ الفكرة'),
            ),
          ),
        ],
      ),
    );
  }
}

class _IdeaCard extends StatelessWidget {
  const _IdeaCard({
    required this.idea,
    required this.canDelete,
    required this.onDelete,
  });

  final ManagerIdea idea;
  final bool canDelete;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final date = intl.DateFormat('yyyy/MM/dd · HH:mm').format(idea.createdAt);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFDCE4EE)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFF45CDA0).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(
              Icons.tips_and_updates_outlined,
              color: Color(0xFF138B68),
              size: 21,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  idea.content,
                  style: const TextStyle(
                    color: Color(0xFF26364A),
                    fontSize: 15,
                    height: 1.55,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      '${idea.authorName} · $date',
                      style: const TextStyle(
                        color: Color(0xFF758195),
                        fontSize: 12,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE6AD36).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: const Text(
                        'بانتظار التنفيذ',
                        style: TextStyle(
                          color: Color(0xFF9A6810),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (canDelete)
            IconButton(
              tooltip: context.tr('حذف الفكرة'),
              onPressed: onDelete,
              color: AppColors.statusRejected,
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFE8EDF4),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        '$count',
        style: const TextStyle(
          color: Color(0xFF536174),
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _IdeasMessage extends StatelessWidget {
  const _IdeasMessage({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 42, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFDCE4EE)),
      ),
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFF93A0B2), size: 38),
          const SizedBox(height: 10),
          Text(message, style: const TextStyle(color: Color(0xFF6C788A))),
        ],
      ),
    );
  }
}
