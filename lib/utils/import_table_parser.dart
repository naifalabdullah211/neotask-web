import 'dart:typed_data';
import 'dart:convert';

import 'package:excel/excel.dart';

class ImportedTable {
  const ImportedTable({required this.headers, required this.rows});

  final List<String> headers;
  final List<Map<String, String>> rows;
}

class ImportTableParser {
  ImportTableParser._();

  static ImportedTable parse({
    required String fileName,
    required Uint8List bytes,
  }) {
    final lower = fileName.toLowerCase();
    final matrix = lower.endsWith('.csv')
        ? _parseCsv(utf8.decode(bytes, allowMalformed: false))
        : _parseXlsx(bytes);
    final usable = matrix
        .map((row) => row.map((cell) => cell.trim()).toList())
        .where((row) => row.any((cell) => cell.isNotEmpty))
        .toList();
    if (usable.length < 2) {
      throw const FormatException('الملف لا يحتوي عناوين وصفوف بيانات');
    }
    final headers = usable.first;
    if (headers.any((header) => header.isEmpty)) {
      throw const FormatException('يوجد عنوان عمود فارغ في الصف الأول');
    }
    final normalized = headers.map(normalizeHeader).toList();
    if (normalized.toSet().length != normalized.length) {
      throw const FormatException('يوجد تكرار في عناوين الأعمدة');
    }
    final rows = <Map<String, String>>[];
    for (final row in usable.skip(1)) {
      final values = <String, String>{};
      for (var i = 0; i < normalized.length; i++) {
        values[normalized[i]] = i < row.length ? row[i] : '';
      }
      rows.add(values);
    }
    return ImportedTable(headers: normalized, rows: rows);
  }

  static String normalizeHeader(String input) {
    final value = input
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[\s_\-]+'), '')
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('آ', 'ا');
    const aliases = {
      'الاسم': 'name',
      'اسمالموظف': 'name',
      'name': 'name',
      'employee': 'name',
      'الرقمالوظيفي': 'employeeNumber',
      'رقمالموظف': 'employeeNumber',
      'employeenumber': 'employeeNumber',
      'employeeid': 'employeeNumber',
      'كلمةالمرور': 'password',
      'كلمهالمرور': 'password',
      'password': 'password',
      'عنوانالمهمة': 'title',
      'عنوانالمهمه': 'title',
      'المهمة': 'title',
      'المهمه': 'title',
      'title': 'title',
      'task': 'title',
      'الوصف': 'description',
      'description': 'description',
      'تاريخالبداية': 'startDate',
      'تاريخالبدايه': 'startDate',
      'startdate': 'startDate',
      'تاريخالاستحقاق': 'dueDate',
      'تاريخالنهاية': 'dueDate',
      'تاريخالنهايه': 'dueDate',
      'duedate': 'dueDate',
      'الساعات': 'plannedHours',
      'الساعاتالمخططة': 'plannedHours',
      'plannedhours': 'plannedHours',
      'الأولوية': 'priority',
      'الاولوية': 'priority',
      'priority': 'priority',
      'التصنيف': 'category',
      'category': 'category',
    };
    return aliases[value] ?? value;
  }

  static List<List<String>> _parseXlsx(Uint8List bytes) {
    final workbook = Excel.decodeBytes(bytes);
    for (final table in workbook.tables.values) {
      if (table.rows.isEmpty) continue;
      final rows = table.rows
          .map(
            (row) => row
                .map((cell) => _cellToString(cell?.value))
                .toList(),
          )
          .toList();
      if (rows.any((row) => row.any((cell) => cell.trim().isNotEmpty))) {
        return rows;
      }
    }
    return const [];
  }

  static String _cellToString(CellValue? value) => switch (value) {
    null => '',
    TextCellValue() => value.value.toString(),
    FormulaCellValue() => value.formula,
    IntCellValue() => value.value.toString(),
    DoubleCellValue() => value.value.toString(),
    BoolCellValue() => value.value.toString(),
    DateCellValue() => value.asDateTimeLocal().toIso8601String().split('T').first,
    DateTimeCellValue() => value.asDateTimeLocal().toIso8601String(),
    TimeCellValue() => value.asDuration().toString(),
  };

  static List<List<String>> _parseCsv(String input) {
    final text = input.startsWith('\uFEFF') ? input.substring(1) : input;
    final rows = <List<String>>[];
    var row = <String>[];
    var cell = StringBuffer();
    var quoted = false;
    for (var i = 0; i < text.length; i++) {
      final char = text[i];
      if (char == '"') {
        if (quoted && i + 1 < text.length && text[i + 1] == '"') {
          cell.write('"');
          i++;
        } else {
          quoted = !quoted;
        }
      } else if (char == ',' && !quoted) {
        row.add(cell.toString());
        cell = StringBuffer();
      } else if ((char == '\n' || char == '\r') && !quoted) {
        if (char == '\r' && i + 1 < text.length && text[i + 1] == '\n') i++;
        row.add(cell.toString());
        rows.add(row);
        row = <String>[];
        cell = StringBuffer();
      } else {
        cell.write(char);
      }
    }
    if (cell.isNotEmpty || row.isNotEmpty) {
      row.add(cell.toString());
      rows.add(row);
    }
    if (rows.isNotEmpty && rows.first.length == 1 && rows.first.first.contains(';')) {
      return rows.map((line) => line.first.split(';')).toList();
    }
    return rows;
  }
}
