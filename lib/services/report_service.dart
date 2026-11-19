import 'package:excel/excel.dart' as excel_lib;
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/balance_model.dart';
import '../models/expense_model.dart';
import '../models/group_model.dart';
import 'report_exporter_stub.dart'
    if (dart.library.io) 'report_exporter_io.dart'
    if (dart.library.html) 'report_exporter_web.dart'
    as exporter;

/// Servicio de exportación de reportes en Web y plataformas nativas.
class ReportService {
  final _currencyFormat = NumberFormat.currency(
    locale: 'es_CL',
    symbol: '\$',
    decimalDigits: 0,
  );
  final _dateFormat = DateFormat('dd/MM/yyyy');

  Future<void> exportPdfReport({
    required GroupModel group,
    required List<ExpenseModel> expenses,
    required List<MemberBalance> balances,
    required List<SettlementTransaction> settlements,
  }) async {
    final doc = pw.Document();
    final totalAmount = expenses.fold<double>(0, (sum, e) => sum + e.amount);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Text(
              'Reporte de gastos - ${group.name}',
              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.Text('Generado el ${_dateFormat.format(DateTime.now())}'),
          pw.SizedBox(height: 16),
          pw.Text(
            'Total del grupo: ${_currencyFormat.format(totalAmount)}',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 12),
          pw.Text(
            'Detalle de gastos',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          pw.TableHelper.fromTextArray(
            headers: [
              'Fecha',
              'Descripción',
              'Categoría',
              'Pagado por',
              'Monto',
            ],
            data: expenses
                .map(
                  (e) => [
                    _dateFormat.format(e.date),
                    e.description,
                    e.category,
                    e.payersSummary,
                    _currencyFormat.format(e.amount),
                  ],
                )
                .toList(),
          ),
          pw.SizedBox(height: 20),
          pw.Text(
            'Balance por integrante',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          pw.TableHelper.fromTextArray(
            headers: ['Integrante', 'Pagó', 'Le correspondía', 'Balance'],
            data: balances
                .map(
                  (b) => [
                    b.name,
                    _currencyFormat.format(b.totalPaid),
                    _currencyFormat.format(b.totalOwed),
                    _currencyFormat.format(b.balance),
                  ],
                )
                .toList(),
          ),
          pw.SizedBox(height: 20),
          pw.Text(
            'Liquidación sugerida',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          ...settlements.map(
            (s) => pw.Text(
              '${s.fromName} le debe ${_currencyFormat.format(s.amount)} a ${s.toName}',
            ),
          ),
        ],
      ),
    );

    final bytes = await doc.save();
    final filename = _filename(group.name, 'pdf');
    try {
      if (kIsWeb) {
        await exporter.exportPdfForWeb(bytes, filename);
      } else {
        await exporter.exportPdfForNative(bytes, filename);
      }
    } catch (error) {
      throw Exception('No se pudo guardar o compartir el PDF: $error');
    }
  }

  Future<void> exportExcelReport({
    required GroupModel group,
    required List<ExpenseModel> expenses,
    required List<MemberBalance> balances,
  }) async {
    final workbook = excel_lib.Excel.createExcel();

    final expensesSheet = workbook['Gastos'];
    expensesSheet.appendRow([
      excel_lib.TextCellValue('Fecha'),
      excel_lib.TextCellValue('Descripción'),
      excel_lib.TextCellValue('Categoría'),
      excel_lib.TextCellValue('Pagado por'),
      excel_lib.TextCellValue('Monto'),
    ]);
    for (final expense in expenses) {
      expensesSheet.appendRow([
        excel_lib.TextCellValue(_dateFormat.format(expense.date)),
        excel_lib.TextCellValue(expense.description),
        excel_lib.TextCellValue(expense.category),
        excel_lib.TextCellValue(expense.payersSummary),
        excel_lib.DoubleCellValue(expense.amount),
      ]);
    }

    final balanceSheet = workbook['Balances'];
    balanceSheet.appendRow([
      excel_lib.TextCellValue('Integrante'),
      excel_lib.TextCellValue('Pagó'),
      excel_lib.TextCellValue('Le correspondía'),
      excel_lib.TextCellValue('Balance'),
    ]);
    for (final balance in balances) {
      balanceSheet.appendRow([
        excel_lib.TextCellValue(balance.name),
        excel_lib.DoubleCellValue(balance.totalPaid),
        excel_lib.DoubleCellValue(balance.totalOwed),
        excel_lib.DoubleCellValue(balance.balance),
      ]);
    }

    if (workbook.sheets.containsKey('Sheet1')) {
      workbook.delete('Sheet1');
    }

    final bytes = workbook.encode();
    if (bytes == null) {
      throw StateError('No se pudieron generar los datos del archivo Excel.');
    }

    final filename = _filename(group.name, 'xlsx');
    try {
      if (kIsWeb) {
        await exporter.exportExcelForWeb(bytes, filename);
      } else {
        await exporter.exportExcelForNative(bytes, filename);
      }
    } catch (error) {
      throw Exception(
        'No se pudo guardar o compartir el archivo Excel: $error',
      );
    }
  }

  String _filename(String groupName, String extension) {
    final safeGroupName = groupName
        .trim()
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(RegExp(r'\s+'), '_');
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'SplitEasy_${safeGroupName}_$timestamp.$extension';
  }
}
