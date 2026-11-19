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
      final expenses = await _firestoreService.getGroupExpensesOnce(
        widget.group.id,
      );
      final balances = _firestoreService.calculateBalances(
        group: widget.group,
        expenses: expenses,
      );
      final settlements = _firestoreService.simplifyDebts(balances);

      await _reportService.exportPdfReport(
        group: widget.group,
        expenses: expenses,
        balances: balances,
        settlements: settlements,
      );
    } catch (e) {
      _showExportError('No se pudo generar el PDF', e);
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
      final expenses = await _firestoreService.getGroupExpensesOnce(
        widget.group.id,
      );
      final balances = _firestoreService.calculateBalances(
        group: widget.group,
        expenses: expenses,
      );

      await _reportService.exportExcelReport(
        group: widget.group,
        expenses: expenses,
        balances: balances,
      );
    } catch (e) {
      _showExportError('No se pudo generar el Excel', e);
    } finally {
      if (mounted) setState(() => _isGeneratingExcel = false);
    }
  }

  void _showExportError(String message, Object error) {
    if (!mounted) return;
    final fullMessage = '$message: $error';
    setState(() => _errorMessage = fullMessage);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(fullMessage)));
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Exportar reportes')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Exporta el historial de gastos y el balance de "${widget.group.name}".',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: colors.onSurfaceVariant,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 28),
                _ReportOptionCard(
                  icon: Icons.picture_as_pdf_outlined,
                  accentColor: colors.error,
                  title: 'Exportar como PDF',
                  subtitle:
                      'Incluye detalle de gastos, balances y liquidación.',
                  isLoading: _isGeneratingPdf,
                  onTap: _exportPdf,
                ),
                const SizedBox(height: 16),
                _ReportOptionCard(
                  icon: Icons.table_chart_outlined,
                  accentColor: colors.primary,
                  title: 'Exportar como Excel',
                  subtitle:
                      'Dos hojas: gastos y balances, para análisis propio.',
                  isLoading: _isGeneratingExcel,
                  onTap: _exportExcel,
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Text(_errorMessage!, style: TextStyle(color: colors.error)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReportOptionCard extends StatefulWidget {
  final IconData icon;
  final Color accentColor;
  final String title;
  final String subtitle;
  final bool isLoading;
  final VoidCallback onTap;

  const _ReportOptionCard({
    required this.icon,
    required this.accentColor,
    required this.title,
    required this.subtitle,
    required this.isLoading,
    required this.onTap,
  });

  @override
  State<_ReportOptionCard> createState() => _ReportOptionCardState();
}

class _ReportOptionCardState extends State<_ReportOptionCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AnimatedPhysicalModel(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      shape: BoxShape.rectangle,
      borderRadius: BorderRadius.circular(22),
      elevation: _isHovered ? 5 : 1,
      color: colors.surfaceContainerLowest,
      shadowColor: colors.shadow.withValues(alpha: 0.18),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onHover: (hovering) => setState(() => _isHovered = hovering),
          onTap: widget.isLoading ? null : widget.onTap,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: widget.accentColor.withValues(
                      alpha: _isHovered ? 0.18 : 0.12,
                    ),
                    borderRadius: BorderRadius.circular(17),
                  ),
                  child: Icon(widget.icon, size: 28, color: widget.accentColor),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                if (widget.isLoading)
                  SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: widget.accentColor,
                    ),
                  )
                else
                  Icon(
                    Icons.arrow_forward_rounded,
                    color: _isHovered
                        ? widget.accentColor
                        : colors.onSurfaceVariant,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
