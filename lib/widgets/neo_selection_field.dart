import 'package:flutter/material.dart' hide Text;
import 'package:neotask_pro/widgets/localized_text.dart';
import 'package:neotask_pro/l10n/app_i18n.dart';

import '../theme/app_theme.dart';

/// One option displayed by [NeoSelectionField].
class NeoSelectionOption<T> {
  const NeoSelectionOption({
    required this.value,
    required this.label,
    this.subtitle,
    this.icon,
    this.color,
    this.searchTerms = const [],
  });

  final T value;
  final String label;
  final String? subtitle;
  final IconData? icon;
  final Color? color;
  final List<String> searchTerms;
}

/// NeoTask's single-selection control.
///
/// Every list-like choice uses the same compact field in the form and the
/// same bottom sheet on mobile. This replaces mixed segmented controls and
/// platform dropdown menus while preserving each screen's existing values.
class NeoSelectionField<T> extends StatelessWidget {
  const NeoSelectionField({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.placeholder = 'اختر',
    this.sheetTitle,
    this.enabled = true,
    this.requiredSelection = false,
    this.validator,
    this.searchable,
    this.leadingIcon,
    this.helperText,
  });

  final String label;
  final T? value;
  final List<NeoSelectionOption<T>> options;
  final ValueChanged<T>? onChanged;
  final String placeholder;
  final String? sheetTitle;
  final bool enabled;
  final bool requiredSelection;
  final FormFieldValidator<T>? validator;
  final bool? searchable;
  final IconData? leadingIcon;
  final String? helperText;

  NeoSelectionOption<T>? _optionFor(T? current) {
    for (final option in options) {
      if (option.value == current) return option;
    }
    return null;
  }

  Future<void> _open(BuildContext context, FormFieldState<T> field) async {
    if (!enabled || onChanged == null || options.isEmpty) return;
    final selected = await showNeoSelectionSheet<T>(
      context: context,
      title: sheetTitle ?? label,
      value: field.value,
      options: options,
      searchable: searchable ?? options.length > 7,
    );
    if (selected == null || !context.mounted) return;
    field.didChange(selected.value);
    onChanged?.call(selected.value);
  }

  @override
  Widget build(BuildContext context) {
    return FormField<T>(
      initialValue: value,
      validator:
          validator ??
          (requiredSelection
              ? (current) => current == null ? 'يرجى اختيار $label' : null
              : null),
      builder: (field) {
        final selected = _optionFor(field.value);
        return Semantics(
          button: true,
          enabled: enabled,
          label: label,
          value: selected?.label ?? placeholder,
          child: InkWell(
            onTap: () => _open(context, field),
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: InputDecorator(
              isEmpty: selected == null,
              decoration: InputDecoration(
                labelText: label,
                errorText: field.errorText == null
                    ? null
                    : context.tr(field.errorText!),
                helperText: helperText,
                enabled: enabled,
                prefixIcon: leadingIcon == null
                    ? null
                    : Icon(leadingIcon, color: AppColors.deepBlue),
                suffixIcon: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: enabled ? AppColors.deepBlue : AppColors.textSecondary,
                ),
              ),
              child: Row(
                children: [
                  if (selected?.color != null) ...[
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: selected!.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  if (selected?.icon != null) ...[
                    Icon(
                      selected!.icon,
                      size: 20,
                      color: selected.color ?? AppColors.deepBlue,
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: Text(
                      selected?.label ?? placeholder,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: selected == null
                            ? AppColors.textSecondary
                            : AppColors.textPrimary,
                        fontWeight: selected == null
                            ? FontWeight.w400
                            : FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Shows the shared, searchable NeoTask choice sheet.
Future<NeoSelectionOption<T>?> showNeoSelectionSheet<T>({
  required BuildContext context,
  required String title,
  required T? value,
  required List<NeoSelectionOption<T>> options,
  bool searchable = false,
}) {
  return showModalBottomSheet<NeoSelectionOption<T>>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _NeoSelectionSheet<T>(
      title: title,
      value: value,
      options: options,
      searchable: searchable,
    ),
  );
}

class _NeoSelectionSheet<T> extends StatefulWidget {
  const _NeoSelectionSheet({
    required this.title,
    required this.value,
    required this.options,
    required this.searchable,
  });

  final String title;
  final T? value;
  final List<NeoSelectionOption<T>> options;
  final bool searchable;

  @override
  State<_NeoSelectionSheet<T>> createState() => _NeoSelectionSheetState<T>();
}

class _NeoSelectionSheetState<T> extends State<_NeoSelectionSheet<T>> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<NeoSelectionOption<T>> get _filteredOptions {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return widget.options;
    return widget.options.where((option) {
      final haystack = <String>[
        option.label,
        if (option.subtitle != null) option.subtitle!,
        ...option.searchTerms,
      ].join(' ').toLowerCase();
      return haystack.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.78;
    final options = _filteredOptions;

    return Padding(
      padding: EdgeInsets.only(bottom: keyboardInset),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Material(
          color: Colors.white,
          elevation: AppElevation.high,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 4,
                margin: const EdgeInsets.only(top: 10),
                decoration: BoxDecoration(
                  color: AppColors.textSecondary.withValues(alpha: 0.28),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 12, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.title,
                        style: const TextStyle(
                          color: AppColors.deepBlue,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: context.tr('إغلاق'),
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              if (widget.searchable)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: TextField(
                    controller: _searchController,
                    autofocus: false,
                    onChanged: (value) => setState(() => _query = value),
                    decoration: InputDecoration(
                      hintText: context.tr('بحث'),
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                  ),
                ),
              const Divider(height: 1),
              Flexible(
                child: options.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(28),
                        child: Text(
                          'لا توجد نتائج مطابقة',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
                        itemCount: options.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 4),
                        itemBuilder: (context, index) {
                          final option = options[index];
                          final selected = option.value == widget.value;
                          return Material(
                            color: selected
                                ? AppColors.mintAccent.withValues(alpha: 0.1)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            child: ListTile(
                              minTileHeight: 58,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppRadius.md,
                                ),
                                side: BorderSide(
                                  color: selected
                                      ? AppColors.mintAccent.withValues(
                                          alpha: 0.45,
                                        )
                                      : Colors.transparent,
                                ),
                              ),
                              leading: option.icon != null
                                  ? Container(
                                      width: 38,
                                      height: 38,
                                      decoration: BoxDecoration(
                                        color:
                                            (option.color ?? AppColors.deepBlue)
                                                .withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(
                                        option.icon,
                                        color:
                                            option.color ?? AppColors.deepBlue,
                                        size: 20,
                                      ),
                                    )
                                  : option.color != null
                                  ? Center(
                                      widthFactor: 1,
                                      child: Container(
                                        width: 11,
                                        height: 11,
                                        decoration: BoxDecoration(
                                          color: option.color,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    )
                                  : null,
                              title: Text(
                                option.label,
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontWeight: selected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                ),
                              ),
                              subtitle: option.subtitle == null
                                  ? null
                                  : Text(option.subtitle!),
                              trailing: AnimatedContainer(
                                duration: const Duration(milliseconds: 160),
                                width: 25,
                                height: 25,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: selected
                                      ? AppColors.mintAccent
                                      : Colors.transparent,
                                  border: Border.all(
                                    color: selected
                                        ? AppColors.mintAccent
                                        : AppColors.textSecondary.withValues(
                                            alpha: 0.35,
                                          ),
                                  ),
                                ),
                                child: selected
                                    ? const Icon(
                                        Icons.check_rounded,
                                        size: 17,
                                        color: Colors.white,
                                      )
                                    : null,
                              ),
                              onTap: () => Navigator.pop(context, option),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
