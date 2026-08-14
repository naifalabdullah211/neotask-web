import 'package:flutter/material.dart' hide Text;
import 'package:neotask_pro/widgets/localized_text.dart';
import 'package:neotask_pro/l10n/app_i18n.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/contact_model.dart';
import '../../providers/contact_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/neo_workspace_chrome.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({
    super.key,
    required this.currentUserUid,
    required this.isManager,
    this.readOnly = false,
  });

  final String currentUserUid;
  final bool isManager;
  final bool readOnly;

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _addContact() async {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final jobCtrl = TextEditingController();
    final notesCtrl = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('جهة اتصال جديدة'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(labelText: context.tr('الاسم')),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneCtrl,
                decoration: InputDecoration(labelText: context.tr('الهاتف')),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailCtrl,
                decoration: InputDecoration(
                  labelText: context.tr('البريد الإلكتروني'),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: jobCtrl,
                decoration: InputDecoration(
                  labelText: context.tr('المسمى الوظيفي'),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesCtrl,
                decoration: InputDecoration(labelText: context.tr('ملاحظات')),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () {
              if (nameCtrl.text.trim().isEmpty) return;
              Navigator.pop(dialogContext, true);
            },
            child: const Text('إضافة'),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      await context.read<ContactProvider>().addContact(
        name: nameCtrl.text.trim(),
        phone: phoneCtrl.text.trim(),
        email: emailCtrl.text.trim(),
        jobTitle: jobCtrl.text.trim(),
        notes: notesCtrl.text.trim(),
        createdBy: widget.currentUserUid,
      );
    }
  }

  Future<void> _confirmDelete(ContactItem contact) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حذف جهة الاتصال'),
        content: Text('هل تريد حذف "${contact.name}"؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.statusRejected,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await context.read<ContactProvider>().deleteContact(contact.contactId);
    }
  }

  Future<void> _call(String phone) async {
    if (phone.isEmpty) return;
    await launchUrl(Uri.parse('tel:$phone'));
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ContactProvider>();
    final allContacts = provider.search('');
    final contacts = provider.search(_searchCtrl.text);
    final withPhone = allContacts
        .where((contact) => contact.phone.isNotEmpty)
        .length;
    final withEmail = allContacts
        .where((contact) => contact.email.isNotEmpty)
        .length;
    final compact = MediaQuery.sizeOf(context).width < 620;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        centerTitle: false,
        title: const Text(
          'جهات الاتصال',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
        ),
        actions: [
          if (!widget.readOnly)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 12),
              child: compact
                  ? IconButton.filled(
                      tooltip: context.tr('جهة اتصال جديدة'),
                      onPressed: _addContact,
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.mintAccent,
                        foregroundColor: AppColors.navy,
                      ),
                      icon: const Icon(Icons.person_add_alt_1_rounded),
                    )
                  : FilledButton.icon(
                      onPressed: _addContact,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.mintAccent,
                        foregroundColor: AppColors.navy,
                      ),
                      icon: const Icon(
                        Icons.person_add_alt_1_rounded,
                        size: 19,
                      ),
                      label: const Text(
                        'جهة اتصال جديدة',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            NeoWorkspaceMetricsBar(
              items: [
                NeoWorkspaceMetric(
                  label: 'إجمالي جهات الاتصال',
                  value: '${allContacts.length}',
                  icon: Icons.people_alt_outlined,
                  color: const Color(0xFF1F6FD2),
                ),
                NeoWorkspaceMetric(
                  label: 'لديهم رقم هاتف',
                  value: '$withPhone',
                  icon: Icons.call_outlined,
                  color: AppColors.mintAccent,
                ),
                NeoWorkspaceMetric(
                  label: 'لديهم بريد إلكتروني',
                  value: '$withEmail',
                  icon: Icons.mail_outline_rounded,
                  color: AppColors.gold,
                ),
              ],
            ),
            Expanded(
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: AppColors.divider)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const NeoWorkspaceSectionHeader(
                      title: 'دليل جهات الاتصال',
                      subtitle:
                          'ابحث واتصل بالجهات الداخلية والخارجية من مكان واحد',
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                      child: TextField(
                        controller: _searchCtrl,
                        decoration: InputDecoration(
                          hintText: context.tr(
                            'ابحث بالاسم أو المسمى أو رقم الهاتف',
                          ),
                          prefixIcon: const Icon(Icons.search_rounded),
                          suffixIcon: _searchCtrl.text.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: context.tr('مسح البحث'),
                                  onPressed: () {
                                    _searchCtrl.clear();
                                    setState(() {});
                                  },
                                  icon: const Icon(Icons.close_rounded),
                                ),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: contacts.isEmpty
                          ? NeoWorkspaceEmptyState(
                              icon: _searchCtrl.text.isEmpty
                                  ? Icons.contacts_outlined
                                  : Icons.search_off_rounded,
                              title: _searchCtrl.text.isEmpty
                                  ? 'لا توجد جهات اتصال'
                                  : 'لا توجد نتائج مطابقة',
                              message: _searchCtrl.text.isEmpty
                                  ? 'أضف جهات الاتصال المهمة لفريقك لتكون متاحة من مكان واحد.'
                                  : 'جرّب اسمًا أو رقمًا مختلفًا.',
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.all(AppSpacing.lg),
                              itemCount: contacts.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: AppSpacing.md),
                              itemBuilder: (context, index) {
                                final contact = contacts[index];
                                final canDelete =
                                    !widget.readOnly &&
                                    (contact.createdBy ==
                                            widget.currentUserUid ||
                                        widget.isManager);
                                return _ContactCard(
                                  contact: contact,
                                  canDelete: canDelete,
                                  onCall: () => _call(contact.phone),
                                  onDelete: () => _confirmDelete(contact),
                                );
                              },
                            ),
                    ),
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

class _ContactCard extends StatelessWidget {
  const _ContactCard({
    required this.contact,
    required this.canDelete,
    required this.onCall,
    required this.onDelete,
  });

  final ContactItem contact;
  final bool canDelete;
  final VoidCallback onCall;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FBFD),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 23,
            backgroundColor: AppColors.deepBlue,
            foregroundColor: Colors.white,
            child: Text(
              contact.name.isNotEmpty ? contact.name[0].toUpperCase() : '?',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  contact.name,
                  style: AppTextStyles.cardTitle.copyWith(fontSize: 15),
                ),
                if (contact.jobTitle.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(contact.jobTitle, style: AppTextStyles.bodySecondary),
                ],
                if (contact.phone.isNotEmpty || contact.email.isNotEmpty) ...[
                  const SizedBox(height: 9),
                  Wrap(
                    spacing: 8,
                    runSpacing: 7,
                    children: [
                      if (contact.phone.isNotEmpty)
                        _ContactFact(
                          icon: Icons.call_outlined,
                          value: contact.phone,
                        ),
                      if (contact.email.isNotEmpty)
                        _ContactFact(
                          icon: Icons.mail_outline_rounded,
                          value: contact.email,
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (contact.phone.isNotEmpty)
            IconButton.filledTonal(
              tooltip: context.tr('اتصال'),
              onPressed: onCall,
              icon: const Icon(Icons.call_rounded),
            ),
          if (canDelete) ...[
            const SizedBox(width: 4),
            IconButton(
              tooltip: context.tr('حذف'),
              onPressed: onDelete,
              color: AppColors.statusRejected,
              icon: const Icon(Icons.delete_outline_rounded),
            ),
          ],
        ],
      ),
    );
  }
}

class _ContactFact extends StatelessWidget {
  const _ContactFact({required this.icon, required this.value});

  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.textSecondary),
          const SizedBox(width: 5),
          Text(
            value,
            style: AppTextStyles.bodySecondary.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
