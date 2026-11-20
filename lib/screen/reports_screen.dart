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
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFFEAF4FB),
      appBar: AppBar(
        title: Text(
          'Exportar reportes',
          style: theme.textTheme.titleLarge?.copyWith(
            color: const Color(0xFF173B75),
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: const Color(0xFFEAF4FB),
        foregroundColor: const Color(0xFF173B75),
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ReportsHeader(groupName: widget.group.name),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE7F3F8),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: const Icon(
                        Icons.file_download_outlined,
                        color: Color(0xFF087F8C),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Elige un formato',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: const Color(0xFF173B75),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'Preparamos el archivo para compartirlo.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: const Color(0xFF687C8D),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 13),
                _ReportOptionCard(
                  icon: Icons.picture_as_pdf_rounded,
                  accentColor: const Color(0xFFD94E61),
                  title: 'Exportar como PDF',
                  subtitle:
                      'Detalle de gastos, balances y liquidación sugerida.',
                  isLoading: _isGeneratingPdf,
                  onTap: _exportPdf,
                ),
                const SizedBox(height: 12),
                _ReportOptionCard(
                  icon: Icons.table_chart_rounded,
                  accentColor: const Color(0xFF2457C5),
                  title: 'Exportar como Excel',
                  subtitle:
                      'Hojas de gastos y balances para analizar los datos.',
                  isLoading: _isGeneratingExcel,
                  onTap: _exportExcel,
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 14),
                  _ReportErrorCard(message: _errorMessage!),
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
    final theme = Theme.of(context);
    return AnimatedPhysicalModel(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      shape: BoxShape.rectangle,
      borderRadius: BorderRadius.circular(20),
      elevation: _isHovered ? 4 : 1,
      color: Colors.white,
      shadowColor: const Color(0xFF173B75).withValues(alpha: 0.1),
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: widget.accentColor.withValues(alpha: 0.18)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onHover: (hovering) => setState(() => _isHovered = hovering),
          onTap: widget.isLoading ? null : widget.onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: widget.accentColor.withValues(
                      alpha: _isHovered ? 0.16 : 0.11,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(widget.icon, size: 26, color: widget.accentColor),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: const Color(0xFF173B75),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF687C8D),
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
                        : const Color(0xFF687C8D),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReportsHeader extends StatelessWidget {
  const _ReportsHeader({required this.groupName});

  final String groupName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF3B82B8), Color(0xFF69B8D0)],
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF176B87).withValues(alpha: 0.18),
            blurRadius: 22,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            right: -26,
            top: -62,
            child: Container(
              width: 154,
              height: 154,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                    ),
                    child: const Icon(
                      Icons.description_outlined,
                      color: Colors.white,
                      size: 21,
                    ),
                  ),
                  const SizedBox(width: 11),
                  Text(
                    'REPORTES DEL GRUPO',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.92),
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 17),
              Text(
                groupName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                'Exporta el historial de gastos y el balance de tu grupo.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.9),
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 15),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.17),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.folder_copy_outlined,
                      size: 15,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 7),
                    Text(
                      'PDF y Excel disponibles',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReportErrorCard extends StatelessWidget {
  const _ReportErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const errorColor = Color(0xFFD94E61);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: errorColor.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: errorColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: errorColor,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
