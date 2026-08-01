import 'package:flutter/material.dart';

import '../../models/custom_form_model.dart';
import '../../services/workflow_service.dart';
import '../../theme/app_theme.dart';

class PublicFormScreen extends StatefulWidget {
  const PublicFormScreen({super.key, required this.formId});
  final String formId;

  @override
  State<PublicFormScreen> createState() => _PublicFormScreenState();
}

class _PublicFormScreenState extends State<PublicFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, dynamic> _answers = {};
  CustomFormDefinition? _form;
  bool _loading = true;
  bool _saving = false;
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final form = await WorkflowService.loadPublicForm(widget.formId);
    if (!mounted) return;
    setState(() {
      _form = form;
      _loading = false;
      for (final field in form?.fields ?? const <CustomFormField>[]) {
        if (field.type != CustomFieldType.choice && field.type != CustomFieldType.checkbox) {
          _controllers[field.fieldId] = TextEditingController();
        }
        if (field.type == CustomFieldType.checkbox) _answers[field.fieldId] = false;
      }
    });
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_form == null) {
      return const Scaffold(body: Center(child: Text('هذا النموذج غير متاح أو تم إيقافه')));
    }
    if (_submitted) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: Card(child: Padding(padding: EdgeInsets.all(30), child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.check_circle, color: AppColors.mintAccent, size: 64),
          SizedBox(height: 14),
          Text('تم استلام ردك بنجاح', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        ])))),
      );
    }
    final form = _form!;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(22)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Image.asset('assets/images/neotask_brand_header.png', height: 42),
                      const SizedBox(height: 18),
                      Text(form.title, style: const TextStyle(color: Colors.white, fontSize: 27, fontWeight: FontWeight.w900)),
                      if (form.description.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(form.description, style: const TextStyle(color: Colors.white70, height: 1.6)),
                      ],
                    ]),
                  ),
                  const SizedBox(height: 16),
                  ...form.fields.map(_buildField),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: _saving ? null : _submit,
                    child: _saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('إرسال الرد'),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField(CustomFormField field) {
    final requiredLabel = field.isRequired ? ' *' : '';
    Widget child;
    if (field.type == CustomFieldType.choice) {
      child = DropdownButtonFormField<String>(
        decoration: InputDecoration(labelText: '${field.label}$requiredLabel'),
        items: field.options.map((option) => DropdownMenuItem(value: option, child: Text(option))).toList(),
        onChanged: (value) => _answers[field.fieldId] = value,
        validator: (value) => field.isRequired && value == null ? 'هذا الحقل مطلوب' : null,
      );
    } else if (field.type == CustomFieldType.checkbox) {
      child = FormField<bool>(
        initialValue: false,
        validator: (value) => field.isRequired && value != true ? 'يجب تأكيد هذا الحقل' : null,
        builder: (state) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('${field.label}$requiredLabel'),
            value: _answers[field.fieldId] as bool? ?? false,
            onChanged: (value) {
              setState(() => _answers[field.fieldId] = value ?? false);
              state.didChange(value);
            },
          ),
          if (state.hasError) Text(state.errorText!, style: const TextStyle(color: AppColors.statusRejected, fontSize: 12)),
        ]),
      );
    } else {
      child = TextFormField(
        controller: _controllers[field.fieldId],
        maxLines: field.type == CustomFieldType.longText ? 4 : 1,
        keyboardType: field.type == CustomFieldType.number ? TextInputType.number : field.type == CustomFieldType.date ? TextInputType.datetime : TextInputType.text,
        decoration: InputDecoration(labelText: '${field.label}$requiredLabel', hintText: field.type == CustomFieldType.date ? 'YYYY-MM-DD' : null),
        validator: (value) {
          if (field.isRequired && (value == null || value.trim().isEmpty)) return 'هذا الحقل مطلوب';
          if (field.type == CustomFieldType.number && value!.isNotEmpty && num.tryParse(value) == null) return 'أدخل رقمًا صحيحًا';
          if (field.type == CustomFieldType.date && value!.isNotEmpty && DateTime.tryParse(value) == null) return 'استخدم صيغة YYYY-MM-DD';
          return null;
        },
      );
    }
    return Card(margin: const EdgeInsets.only(bottom: 12), child: Padding(padding: const EdgeInsets.all(16), child: child));
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final answers = Map<String, dynamic>.from(_answers);
    for (final entry in _controllers.entries) {
      answers[entry.key] = entry.value.text.trim();
    }
    try {
      await WorkflowService.submitPublicForm(form: _form!, answers: answers);
      if (mounted) setState(() => _submitted = true);
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذّر إرسال الرد. حاول مرة أخرى')));
      }
    }
  }
}
