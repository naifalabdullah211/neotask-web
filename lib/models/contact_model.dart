/// A manually-entered contact card ("جهات الاتصال") — internal team members
/// or external parties (suppliers, clinics, etc.) relevant to the manager's
/// or employee's work. Distinct from [AppUser]: contacts are free-form
/// entries, not app accounts.
class ContactItem {
  final String contactId;
  final String name;
  final String phone;
  final String email;
  final String jobTitle;
  final String notes;
  final String createdBy; // uid
  final DateTime createdAt;

  ContactItem({
    required this.contactId,
    required this.name,
    required this.phone,
    required this.email,
    required this.jobTitle,
    required this.notes,
    required this.createdBy,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'contactId': contactId,
      'name': name,
      'phone': phone,
      'email': email,
      'jobTitle': jobTitle,
      'notes': notes,
      'createdBy': createdBy,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory ContactItem.fromMap(Map<dynamic, dynamic> map) {
    return ContactItem(
      contactId: map['contactId'] as String,
      name: map['name'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      email: map['email'] as String? ?? '',
      jobTitle: map['jobTitle'] as String? ?? '',
      notes: map['notes'] as String? ?? '',
      createdBy: map['createdBy'] as String? ?? '',
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'] as String)
          : DateTime.now(),
    );
  }
}
