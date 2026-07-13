import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/contact_model.dart';
import '../../providers/contact_provider.dart';
import '../../theme/app_theme.dart';

/// Contact directory ("جهات الاتصال") — free-form entries (internal team
/// members or external parties) distinct from app-account users.
class ContactsScreen extends StatefulWidget {
  const ContactsScreen({
    super.key,
    required this.currentUserUid,
    required this.isManager,
    this.readOnly = false,
  });

  final String currentUserUid;
  final bool isManager;

  /// True for the read-only `designer` role — suppresses the
  /// "add contact" FAB. The `tel:` call button is intentionally NOT
  /// suppressed: it launches the device's own dialer via an external
  /// Intent and never writes to Firestore, so it does not violate the
  /// "3-no" zero-write-access requirement.
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
      builder: (context) => AlertDialog(
        title: const Text('جهة اتصال جديدة'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'الاسم'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneCtrl,
                decoration: const InputDecoration(labelText: 'الهاتف'),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailCtrl,
                decoration: const InputDecoration(
                  labelText: 'البريد الإلكتروني',
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: jobCtrl,
                decoration: const InputDecoration(labelText: 'المسمى الوظيفي'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesCtrl,
                decoration: const InputDecoration(labelText: 'ملاحظات'),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () {
              if (nameCtrl.text.trim().isEmpty) return;
              Navigator.pop(context, true);
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
      builder: (context) => AlertDialog(
        title: const Text('حذف جهة الاتصال'),
        content: Text('هل تريد حذف "${contact.name}"؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.statusRejected,
            ),
            onPressed: () => Navigator.pop(context, true),
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
    final contacts = provider.search(_searchCtrl.text);

    return Scaffold(
      appBar: AppBar(title: const Text('جهات الاتصال')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchCtrl,
                decoration: const InputDecoration(
                  labelText: 'بحث',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            Expanded(
              child: contacts.isEmpty
                  ? const Center(
                      child: Text(
                        'لا توجد جهات اتصال',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: contacts.length,
                      itemBuilder: (context, index) {
                        final c = contacts[index];
                        final canDelete =
                            c.createdBy == widget.currentUserUid ||
                            widget.isManager;
                        return Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppColors.deepBlue,
                              child: Text(
                                c.name.isNotEmpty ? c.name[0] : '?',
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                            title: Text(
                              c.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              [
                                if (c.jobTitle.isNotEmpty) c.jobTitle,
                                if (c.phone.isNotEmpty) c.phone,
                              ].join(' · '),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (c.phone.isNotEmpty)
                                  IconButton(
                                    icon: const Icon(
                                      Icons.call_outlined,
                                      color: AppColors.emerald,
                                    ),
                                    onPressed: () => _call(c.phone),
                                  ),
                                if (canDelete)
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      color: AppColors.statusRejected,
                                    ),
                                    onPressed: () => _confirmDelete(c),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: widget.readOnly
          ? null
          : FloatingActionButton(
              onPressed: _addContact,
              child: const Icon(Icons.person_add_outlined),
            ),
    );
  }
}
