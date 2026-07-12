import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/contact_model.dart';
import '../services/firestore_service.dart';

class ContactProvider extends ChangeNotifier {
  static const _uuid = Uuid();

  List<ContactItem> _contacts = [];
  List<ContactItem> get contacts => _contacts;

  ContactProvider() {
    _listen();
  }

  void _listen() {
    FirestoreService.watchAllContacts().listen((items) {
      _contacts = items;
      notifyListeners();
    });
  }

  List<ContactItem> search(String query) {
    if (query.trim().isEmpty) return _contacts;
    final q = query.trim().toLowerCase();
    return _contacts
        .where(
          (c) =>
              c.name.toLowerCase().contains(q) ||
              c.phone.toLowerCase().contains(q) ||
              c.jobTitle.toLowerCase().contains(q),
        )
        .toList();
  }

  Future<void> addContact({
    required String name,
    required String phone,
    required String email,
    required String jobTitle,
    required String notes,
    required String createdBy,
  }) async {
    final contact = ContactItem(
      contactId: _uuid.v4(),
      name: name,
      phone: phone,
      email: email,
      jobTitle: jobTitle,
      notes: notes,
      createdBy: createdBy,
      createdAt: DateTime.now(),
    );
    await FirestoreService.saveContact(contact);
  }

  Future<void> deleteContact(String contactId) async {
    await FirestoreService.deleteContact(contactId);
  }
}
