import 'dart:io';
import 'package:excel/excel.dart' as excel_lib;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import '../models/expense_model.dart';
import '../models/group_model.dart';
import '../models/balance_model.dart';

/// Servicio de exportación de reportes (Requerimiento funcional:
/// "Generar reportes exportables en PDF y Excel").
class ReportService {
  final _currencyFormat = NumberFormat.currency(
    locale: 'es_CL',
    symbol: '\$',
    decimalDigits: 0,
  );
  final _dateFormat = DateFormat('dd/MM/yyyy');

  // ---------------------------------------------------------------------
  // PDF
  // ---------------------------------------------------------------------

  Future<File> generatePdfReport({
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
            child: pw.Text('Reporte de gastos - ${group.name}',
                style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
          ),
          pw.Text('Generado el ${_dateFormat.format(DateTime.now())}'),
          pw.SizedBox(height: 16),

          pw.Text('Total del grupo: ${_currencyFormat.format(totalAmount)}',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 12),

          pw.Text('Detalle de gastos',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          pw.Table.fromTextArray(
            headers: ['Fecha', 'Descripción', 'Categoría', 'Pagado por', 'Monto'],
            data: expenses
                .map((e) => [
                      _dateFormat.format(e.date),
                      e.description,
                      e.category,
                      e.payersSummary,
                      _currencyFormat.format(e.amount),
                    ])
                .toList(),
          ),
          pw.SizedBox(height: 20),

          pw.Text('Balance por integrante',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          pw.Table.fromTextArray(
            headers: ['Integrante', 'Pagó', 'Le correspondía', 'Balance'],
            data: balances
                .map((b) => [
                      b.name,
                      _currencyFormat.format(b.totalPaid),
                      _currencyFormat.format(b.totalOwed),
                      _currencyFormat.format(b.balance),
                    ])
                .toList(),
          ),
          pw.SizedBox(height: 20),

          pw.Text('Liquidación sugerida',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          ...settlements.map(
            (s) => pw.Text(
                '${s.fromName} le debe ${_currencyFormat.format(s.amount)} a ${s.toName}'),
          ),
        ],
      ),
    );

    final dir = await getApplicationDocumentsDirectory();
    final file = File(
        '${dir.path}/SplitEasy_${group.name}_${DateTime.now().millisecondsSinceEpoch}.pdf');
    await file.writeAsBytes(await doc.save());
    return file;
  }

  // ---------------------------------------------------------------------
  // EXCEL
  // ---------------------------------------------------------------------

  Future<File> generateExcelReport({
    required GroupModel group,
    required List<ExpenseModel> expenses,
    required List<MemberBalance> balances,
  }) async {
    final workbook = excel_lib.Excel.createExcel();

    // Hoja de gastos
    final expensesSheet = workbook['Gastos'];
    expensesSheet.appendRow([
      excel_lib.TextCellValue('Fecha'),
      excel_lib.TextCellValue('Descripción'),
      excel_lib.TextCellValue('Categoría'),
      excel_lib.TextCellValue('Pagado por'),
      excel_lib.TextCellValue('Monto'),
    ]);
    for (final e in expenses) {
      expensesSheet.appendRow([
        excel_lib.TextCellValue(_dateFormat.format(e.date)),
        excel_lib.TextCellValue(e.description),
        excel_lib.TextCellValue(e.category),
        excel_lib.TextCellValue(e.payersSummary),
        excel_lib.DoubleCellValue(e.amount),
      ]);
    }

    // Hoja de balances
    final balanceSheet = workbook['Balances'];
    balanceSheet.appendRow([
      excel_lib.TextCellValue('Integrante'),
      excel_lib.TextCellValue('Pagó'),
      excel_lib.TextCellValue('Le correspondía'),
      excel_lib.TextCellValue('Balance'),
    ]);
    for (final b in balances) {
      balanceSheet.appendRow([
        excel_lib.TextCellValue(b.name),
        excel_lib.DoubleCellValue(b.totalPaid),
        excel_lib.DoubleCellValue(b.totalOwed),
        excel_lib.DoubleCellValue(b.balance),
      ]);
    }

    // Elimina la hoja default vacía "Sheet1" si quedó
    if (workbook.sheets.containsKey('Sheet1')) {
      workbook.delete('Sheet1');
    }

    final dir = await getApplicationDocumentsDirectory();
    final file = File(
        '${dir.path}/SplitEasy_${group.name}_${DateTime.now().millisecondsSinceEpoch}.xlsx');
    final bytes = workbook.encode();
    if (bytes != null) {
      await file.writeAsBytes(bytes);
    }
    return file;
  }

  /// Comparte el archivo generado usando el selector nativo del sistema
  Future<void> shareFile(File file) async {
    await Share.shareXFiles([XFile(file.path)]);
  }
}
