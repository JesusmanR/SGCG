import 'dart:convert';
import 'dart:io';

import 'package:excel/excel.dart';
import 'package:file_selector/file_selector.dart';
import 'package:pdf/pdf.dart' as pdf;
import 'package:pdf/widgets.dart' as pw;

import 'app_database.dart';

class ReportExportService {
  Future<String?> exportCsv({
    required List<Expense> expenses,
    required List<IncomeRecord> incomes,
    required Map<String, String> categories,
    required DateTime start,
    required DateTime end,
    required int totalCents,
    required int incomeCents,
  }) async {
    final location = await getSaveLocation(
      suggestedName: 'gastos_${_dateStamp(start)}_${_dateStamp(end)}.csv',
      acceptedTypeGroups: const [
        XTypeGroup(label: 'CSV', extensions: ['csv']),
      ],
    );
    if (location == null) return null;
    final rows = <List<String>>[
      ['Informe de gastos'],
      ['Periodo', '${_date(start)} - ${_date(end)}'],
      ['Ingresos COP', (incomeCents / 100).toStringAsFixed(2)],
      ['Gastos COP', (totalCents / 100).toStringAsFixed(2)],
      ['Saldo neto COP', ((incomeCents - totalCents) / 100).toStringAsFixed(2)],
      [],
      [
        'Tipo',
        'Fecha',
        'Nombre',
        'Categoría',
        'Método de pago',
        'Comercio',
        'Nota',
        'Valor COP',
      ],
      for (final expense in expenses)
        [
          'Gasto',
          _date(expense.expenseDate),
          expense.name,
          categories[expense.categoryId] ?? 'Archivada',
          expense.paymentMethod ?? '',
          expense.merchant ?? '',
          expense.notes ?? '',
          (expense.amountCents / 100).toStringAsFixed(2),
        ],
      for (final income in incomes)
        [
          'Ingreso',
          _date(income.incomeDate),
          income.name,
          '',
          '',
          income.source ?? '',
          income.notes ?? '',
          (income.amountCents / 100).toStringAsFixed(2),
        ],
    ];
    final csv = rows.map((row) => row.map(_csvField).join(';')).join('\r\n');
    await File(location.path)
        .writeAsBytes([0xEF, 0xBB, 0xBF, ...utf8.encode(csv)]);
    return location.path;
  }

  Future<String?> exportExcel({
    required List<Expense> expenses,
    required List<IncomeRecord> incomes,
    required Map<String, String> categories,
    required DateTime start,
    required DateTime end,
    required int totalCents,
    required int incomeCents,
  }) async {
    final location = await getSaveLocation(
      suggestedName: 'gastos_${_dateStamp(start)}_${_dateStamp(end)}.xlsx',
      acceptedTypeGroups: const [
        XTypeGroup(label: 'Excel', extensions: ['xlsx']),
      ],
    );
    if (location == null) return null;
    final workbook = Excel.createExcel();
    final sheet = workbook['Gastos'];
    sheet.appendRow([TextCellValue('Informe de ingresos y gastos')]);
    sheet.appendRow([
      TextCellValue('Periodo'),
      TextCellValue('${_date(start)} - ${_date(end)}'),
    ]);
    sheet.appendRow([
      TextCellValue('Ingresos COP'),
      DoubleCellValue(incomeCents / 100),
    ]);
    sheet.appendRow([
      TextCellValue('Gastos COP'),
      DoubleCellValue(totalCents / 100),
    ]);
    sheet.appendRow([
      TextCellValue('Saldo neto COP'),
      DoubleCellValue((incomeCents - totalCents) / 100),
    ]);
    sheet.appendRow([
      TextCellValue('Tipo'),
      TextCellValue('Fecha'),
      TextCellValue('Nombre'),
      TextCellValue('Categoría'),
      TextCellValue('Método de pago'),
      TextCellValue('Comercio'),
      TextCellValue('Nota'),
      TextCellValue('Valor COP'),
    ]);
    for (final expense in expenses) {
      sheet.appendRow([
        TextCellValue('Gasto'),
        TextCellValue(_date(expense.expenseDate)),
        TextCellValue(expense.name),
        TextCellValue(categories[expense.categoryId] ?? 'Archivada'),
        TextCellValue(expense.paymentMethod ?? ''),
        TextCellValue(expense.merchant ?? ''),
        TextCellValue(expense.notes ?? ''),
        DoubleCellValue(expense.amountCents / 100),
      ]);
    }
    for (final income in incomes) {
      sheet.appendRow([
        TextCellValue('Ingreso'),
        TextCellValue(_date(income.incomeDate)),
        TextCellValue(income.name),
        TextCellValue(''),
        TextCellValue(''),
        TextCellValue(income.source ?? ''),
        TextCellValue(income.notes ?? ''),
        DoubleCellValue(income.amountCents / 100),
      ]);
    }
    final bytes = workbook.encode();
    if (bytes == null) throw StateError('No se pudo crear el archivo Excel.');
    await File(location.path).writeAsBytes(bytes, flush: true);
    return location.path;
  }

  Future<String?> exportPdf({
    required List<Expense> expenses,
    required List<IncomeRecord> incomes,
    required Map<String, String> categories,
    required DateTime start,
    required DateTime end,
    required int totalCents,
    required int incomeCents,
  }) async {
    final location = await getSaveLocation(
      suggestedName: 'gastos_${_dateStamp(start)}_${_dateStamp(end)}.pdf',
      acceptedTypeGroups: const [
        XTypeGroup(label: 'PDF', extensions: ['pdf']),
      ],
    );
    if (location == null) return null;
    final document = pw.Document();
    document.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Text(
            'Informe de ingresos y gastos',
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.Text('Periodo: ${_date(start)} - ${_date(end)}'),
          pw.Text('Ingresos: COP ${(incomeCents / 100).toStringAsFixed(2)}'),
          pw.Text('Gastos: COP ${(totalCents / 100).toStringAsFixed(2)}'),
          pw.Text(
            'Saldo neto: COP ${((incomeCents - totalCents) / 100).toStringAsFixed(2)}',
          ),
          pw.Text('Movimientos: ${expenses.length + incomes.length}'),
          pw.SizedBox(height: 16),
          pw.TableHelper.fromTextArray(
            headers: const [
              'Tipo',
              'Fecha',
              'Nombre',
              'Categoría',
              'Pago',
              'Valor COP',
            ],
            data: [
              for (final expense in expenses)
                [
                  'Gasto',
                  _date(expense.expenseDate),
                  expense.name,
                  categories[expense.categoryId] ?? 'Archivada',
                  expense.paymentMethod ?? '—',
                  (expense.amountCents / 100).toStringAsFixed(2),
                ],
              for (final income in incomes)
                [
                  'Ingreso',
                  _date(income.incomeDate),
                  income.name,
                  '—',
                  income.source ?? '—',
                  (income.amountCents / 100).toStringAsFixed(2),
                ],
            ],
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            headerDecoration: pw.BoxDecoration(
              color: pdf.PdfColor(0.91, 0.94, 0.92),
            ),
            cellStyle: const pw.TextStyle(fontSize: 8),
            cellAlignment: pw.Alignment.centerLeft,
          ),
        ],
      ),
    );
    await File(location.path).writeAsBytes(await document.save(), flush: true);
    return location.path;
  }
}

String _csvField(String value) => '"${value.replaceAll('"', '""')}"';

String _date(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

String _dateStamp(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
