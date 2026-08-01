enum CustomFieldType { shortText, longText, number, date, choice, checkbox }

class CustomFormField {
  const CustomFormField({
    required this.fieldId,
    required this.label,
    required this.type,
    required this.isRequired,
    this.options = const [],
  });

  final String fieldId;
  final String label;
  final CustomFieldType type;
  final bool isRequired;
  final List<String> options;

  Map<String, dynamic> toMap() => {
    'fieldId': fieldId,
    'label': label,
    'type': type.name,
    'isRequired': isRequired,
    'options': options,
  };

  factory CustomFormField.fromMap(Map<String, dynamic> map) => CustomFormField(
    fieldId: map['fieldId'] as String? ?? '',
    label: map['label'] as String? ?? '',
    type: CustomFieldType.values.where((e) => e.name == map['type']).firstOrNull ??
        CustomFieldType.shortText,
    isRequired: map['isRequired'] as bool? ?? false,
    options: List<String>.from(map['options'] as List? ?? const []),
  );
}

class CustomFormDefinition {
  const CustomFormDefinition({
    required this.formId,
    required this.title,
    required this.description,
    required this.isActive,
    required this.fields,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  final String formId;
  final String title;
  final String description;
  final bool isActive;
  final List<CustomFormField> fields;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, dynamic> toMap() => {
    'formId': formId,
    'title': title,
    'description': description,
    'isActive': isActive,
    'fields': fields.map((field) => field.toMap()).toList(),
    'createdBy': createdBy,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory CustomFormDefinition.fromMap(Map<String, dynamic> map) =>
      CustomFormDefinition(
        formId: map['formId'] as String? ?? '',
        title: map['title'] as String? ?? '',
        description: map['description'] as String? ?? '',
        isActive: map['isActive'] as bool? ?? false,
        fields: (map['fields'] as List? ?? const [])
            .map((field) => CustomFormField.fromMap(
                  Map<String, dynamic>.from(field as Map),
                ))
            .toList(),
        createdBy: map['createdBy'] as String? ?? '',
        createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ??
            DateTime.now(),
        updatedAt: DateTime.tryParse(map['updatedAt'] as String? ?? '') ??
            DateTime.now(),
      );
}

class CustomFormResponse {
  const CustomFormResponse({
    required this.responseId,
    required this.formId,
    required this.answers,
    required this.submittedAt,
  });

  final String responseId;
  final String formId;
  final Map<String, dynamic> answers;
  final DateTime submittedAt;

  factory CustomFormResponse.fromMap(Map<String, dynamic> map) =>
      CustomFormResponse(
        responseId: map['responseId'] as String? ?? '',
        formId: map['formId'] as String? ?? '',
        answers: Map<String, dynamic>.from(map['answers'] as Map? ?? const {}),
        submittedAt: DateTime.tryParse(map['submittedAt'] as String? ?? '') ??
            DateTime.now(),
      );
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
