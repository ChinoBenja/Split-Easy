import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../models/group_model.dart';
import '../../services/firestore_service.dart';
import '../../services/report_service.dart';
import '../widgets/main_navigation_bar.dart';
import 'add_expense_screen.dart';
import 'assistant_chat_screen.dart';
import 'create_group_screen.dart';
import 'profile_screen.dart';

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
  Future<String?>? _userPhotoFuture;

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      _userPhotoFuture = _firestoreService.getUserPhoto(uid);
    }
  }

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
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ReportsHeader(groupName: widget.group.name),
                const SizedBox(height: 26),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF087F8C), Color(0xFF20A6A7)],
                        ),
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFF087F8C,
                            ).withValues(alpha: 0.2),
                            blurRadius: 12,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.file_download_outlined,
                        color: Colors.white,
                        size: 21,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '¿Cómo quieres tu reporte?',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: const Color(0xFF173B75),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Elige el formato que mejor se adapte a ti.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: const Color(0xFF687C8D),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                const _ReportContentsStrip(),
                const SizedBox(height: 16),
                _ReportOptionCard(
                  icon: Icons.picture_as_pdf_rounded,
                  accentColor: const Color(0xFFD94E61),
                  formatLabel: 'IDEAL PARA COMPARTIR',
                  title: 'Reporte en PDF',
                  subtitle:
                      'Gastos, balances y liquidación sugerida en un documento listo para enviar.',
                  isLoading: _isGeneratingPdf,
                  onTap: _exportPdf,
                ),
                const SizedBox(height: 13),
                _ReportOptionCard(
                  icon: Icons.table_chart_rounded,
                  accentColor: const Color(0xFF2457C5),
                  formatLabel: 'IDEAL PARA ANALIZAR',
                  title: 'Planilla Excel',
                  subtitle:
                      'Organiza y revisa los gastos y balances en hojas de cálculo.',
                  isLoading: _isGeneratingExcel,
                  onTap: _exportExcel,
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 14),
                  _ReportErrorCard(message: _errorMessage!),
                ],
                const SizedBox(height: 16),
                const _ReportPrivacyNote(),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: MainNavigationBar(
        onHomeTap: () =>
            Navigator.of(context).popUntil((route) => route.isFirst),
        onGroupsTap: _openGroups,
        onAssistantTap: () => _navigateTo(const AssistantChatScreen()),
        onCreateGroupTap: () => _navigateTo(const CreateGroupScreen()),
        onAddExpenseTap: () =>
            _navigateTo(AddExpenseScreen(group: widget.group)),
        onProfileTap: _openProfile,
        profilePhotoFuture: _userPhotoFuture ?? Future<String?>.value(null),
      ),
    );
  }

  Future<void> _openGroups() async {
    final navigator = Navigator.of(context);
    await navigator.maybePop();
    if (navigator.canPop()) await navigator.maybePop();
  }

  Future<void> _openProfile() async {
    await _navigateTo(const ProfileScreen());
    if (!mounted) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      setState(() {
        _userPhotoFuture = _firestoreService.getUserPhoto(uid);
      });
    }
  }

  Future<void> _navigateTo(Widget screen) {
    return Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => screen));
  }
}

class _ReportOptionCard extends StatefulWidget {
  final IconData icon;
  final Color accentColor;
  final String formatLabel;
  final String title;
  final String subtitle;
  final bool isLoading;
  final VoidCallback onTap;

  const _ReportOptionCard({
    required this.icon,
    required this.accentColor,
    required this.formatLabel,
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
            padding: const EdgeInsets.fromLTRB(15, 16, 15, 16),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        widget.accentColor.withValues(
                          alpha: _isHovered ? 0.19 : 0.14,
                        ),
                        widget.accentColor.withValues(alpha: 0.07),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(19),
                  ),
                  child: Icon(widget.icon, size: 29, color: widget.accentColor),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.formatLabel,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: widget.accentColor,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.55,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: const Color(0xFF173B75),
                          fontWeight: FontWeight.w800,
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
                const SizedBox(width: 10),
                if (widget.isLoading)
                  SizedBox(
                    width: 34,
                    height: 34,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: widget.accentColor,
                    ),
                  )
                else
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: widget.accentColor.withValues(
                        alpha: _isHovered ? 0.14 : 0.08,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      size: 19,
                      color: widget.accentColor,
                    ),
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
    final textWidth = (MediaQuery.sizeOf(context).width - 180)
        .clamp(120.0, 250.0)
        .toDouble();
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
          Positioned(right: 3, top: 5, child: _ReportDocumentPreview()),
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
                  Expanded(
                    child: Text(
                      'REPORTES DEL GRUPO',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.92),
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),
                  const SizedBox(width: 82),
                ],
              ),
              const SizedBox(height: 19),
              SizedBox(
                width: textWidth,
                child: Text(
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
              ),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: textWidth),
                child: Text(
                  'Todo lo que tu grupo necesita, organizado en un solo reporte.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.92),
                    height: 1.35,
                  ),
                ),
              ),
              const SizedBox(height: 18),
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
                      Icons.verified_rounded,
                      size: 15,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 7),
                    Text(
                      'Información actualizada del grupo',
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

class _ReportDocumentPreview extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: 0.12,
      child: Container(
        width: 74,
        height: 94,
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.38)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF174B79).withValues(alpha: 0.12),
              blurRadius: 15,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.description_rounded,
              color: Colors.white,
              size: 23,
            ),
            const SizedBox(height: 9),
            ...List.generate(
              3,
              (index) => Container(
                height: 3,
                width: index == 2 ? 28 : 43,
                margin: const EdgeInsets.only(bottom: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportContentsStrip extends StatelessWidget {
  const _ReportContentsStrip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDCE8EF)),
      ),
      child: const Row(
        children: [
          Expanded(
            child: _ReportContentItem(
              icon: Icons.receipt_long_rounded,
              label: 'Gastos',
            ),
          ),
          _ReportContentDivider(),
          Expanded(
            child: _ReportContentItem(
              icon: Icons.account_balance_wallet_rounded,
              label: 'Balances',
            ),
          ),
          _ReportContentDivider(),
          Expanded(
            child: _ReportContentItem(
              icon: Icons.swap_horiz_rounded,
              label: 'Pagos',
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportContentItem extends StatelessWidget {
  const _ReportContentItem({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 17, color: const Color(0xFF087F8C)),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: const Color(0xFF35536D),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _ReportContentDivider extends StatelessWidget {
  const _ReportContentDivider();

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 20, color: const Color(0xFFDCE8EF));
  }
}

class _ReportPrivacyNote extends StatelessWidget {
  const _ReportPrivacyNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFE3F2F4),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 19,
            color: Color(0xFF087F8C),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'El archivo se prepara con los datos actuales de este grupo.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: const Color(0xFF35536D),
                height: 1.35,
              ),
            ),
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
