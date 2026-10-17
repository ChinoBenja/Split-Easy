import 'package:flutter/material.dart';
import '../../models/group_model.dart';
import '../../services/firestore_service.dart';
import '../../services/report_service.dart';

/// Pantalla de exportación de reportes (Requerimiento funcional:
/// "Generar reportes exportables en PDF y Excel")
class ReportsScreen extends StatefulWidget {
  final GroupModel group;
  const ReportsScreen({super.key, required this.group});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final _firestoreService = FirestoreService();
  final _reportService = ReportService();
  bool _isGeneratingPdf = false;
  bool _isGeneratingExcel = false;
  String? _errorMessage;

  Future<void> _exportPdf() async {
    setState(() {
      _isGeneratingPdf = true;
      _errorMessage = null;
    });
    try {
      final expenses =
          await _firestoreService.getGroupExpensesOnce(widget.group.id);
      final balances = _firestoreService.calculateBalances(
        group: widget.group,
        expenses: expenses,
      );
      final settlements = _firestoreService.simplifyDebts(balances);

      final file = await _reportService.generatePdfReport(
        group: widget.group,
        expenses: expenses,
        balances: balances,
        settlements: settlements,
      );
      await _reportService.shareFile(file);
    } catch (e) {
      setState(() => _errorMessage = 'No se pudo generar el PDF: $e');
    } finally {
      if (mounted) setState(() => _isGeneratingPdf = false);
    }
  }

  Future<void> _exportExcel() async {
    setState(() {
      _isGeneratingExcel = true;
      _errorMessage = null;
    });
    try {
      final expenses =
          await _firestoreService.getGroupExpensesOnce(widget.group.id);
      final balances = _firestoreService.calculateBalances(
        group: widget.group,
        expenses: expenses,
      );

      final file = await _reportService.generateExcelReport(
        group: widget.group,
        expenses: expenses,
        balances: balances,
      );
      await _reportService.shareFile(file);
    } catch (e) {
      setState(() => _errorMessage = 'No se pudo generar el Excel: $e');
    } finally {
      if (mounted) setState(() => _isGeneratingExcel = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Exportar reportes')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Exporta el historial de gastos y el balance de "${widget.group.name}".',
              style: TextStyle(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 24),

            _ReportOptionCard(
              icon: Icons.picture_as_pdf_outlined,
              title: 'Exportar como PDF',
              subtitle: 'Incluye detalle de gastos, balances y liquidación.',
              isLoading: _isGeneratingPdf,
              onTap: _exportPdf,
            ),
            const SizedBox(height: 16),
            _ReportOptionCard(
              icon: Icons.table_chart_outlined,
              title: 'Exportar como Excel',
              subtitle: 'Dos hojas: gastos y balances, para análisis propio.',
              isLoading: _isGeneratingExcel,
              onTap: _exportExcel,
            ),

            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
            ],
          ],
        ),
      ),
    );
  }
}

class _ReportOptionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isLoading;
  final VoidCallback onTap;

  const _ReportOptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon, size: 32),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.chevron_right),
        onTap: isLoading ? null : onTap,
      ),
    );
  }
}
