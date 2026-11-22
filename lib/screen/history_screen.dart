import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/group_model.dart';
import '../../models/history_entry_model.dart';
import '../../models/settlement_record_model.dart';
import '../../services/firestore_service.dart';
import '../widgets/main_navigation_bar.dart';
import 'add_expense_screen.dart';
import 'assistant_chat_screen.dart';
import 'create_group_screen.dart';
import 'profile_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key, required this.group});

  final GroupModel group;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _firestoreService = FirestoreService();
  Future<String?>? _userPhotoFuture;

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      _userPhotoFuture = _firestoreService.getUserPhoto(uid);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('dd MMM yyyy · HH:mm', 'es');

    return Scaffold(
      backgroundColor: const Color(0xFFEAF4FB),
      appBar: AppBar(
        title: Text(
          'Historial de cambios',
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
      body: StreamBuilder<List<HistoryEntry>>(
        stream: _firestoreService.watchHistory(widget.group.id),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _HistoryMessage(
              icon: Icons.cloud_off_rounded,
              title: 'No se pudo cargar el historial',
              message: 'Revisa tu conexión e inténtalo nuevamente.',
              isError: true,
            );
          }
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF2457C5)),
            );
          }

          final entries = snapshot.data!;
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 880),
              child: entries.isEmpty
                  ? _HistoryMessage(
                      icon: Icons.history_rounded,
                      title: 'Aún no hay movimientos',
                      message:
                          'Los cambios y actividades del grupo aparecerán aquí.',
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                      children: [
                        _HistoryHeader(
                          groupName: widget.group.name,
                          entryCount: entries.length,
                          memberCount: widget.group.memberIds.length,
                        ),
                        const SizedBox(height: 25),
                        _ActivitySectionHeading(
                          entryCount: entries.length,
                          style: theme.textTheme,
                        ),
                        const SizedBox(height: 15),
                        ...List.generate(entries.length, (index) {
                          final entry = entries[index];
                          return _HistoryTimelineItem(
                            entry: entry,
                            dateLabel: dateFormat.format(entry.createdAt),
                            config: _configFor(entry.action),
                            isLast: index == entries.length - 1,
                            groupId: widget.group.id,
                          );
                        }),
                      ],
                    ),
            ),
          );
        },
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

  _HistoryConfig _configFor(String action) {
    switch (action) {
      case 'created':
        return const _HistoryConfig(
          Icons.add_circle_outline_rounded,
          Color(0xFF2E9D68),
          'creó',
          'GASTO CREADO',
        );
      case 'edit_proposed':
        return const _HistoryConfig(
          Icons.edit_note_rounded,
          Color(0xFF2457C5),
          'propuso editar',
          'EDICIÓN PROPUESTA',
        );
      case 'edit_approved':
        return const _HistoryConfig(
          Icons.check_circle_outline_rounded,
          Color(0xFF2E9D68),
          'editó (aprobado)',
          'EDICIÓN APROBADA',
        );
      case 'edit_rejected':
        return const _HistoryConfig(
          Icons.cancel_outlined,
          Color(0xFFD94E61),
          'intentó editar (rechazado)',
          'EDICIÓN RECHAZADA',
        );
      case 'delete_proposed':
        return const _HistoryConfig(
          Icons.delete_outline_rounded,
          Color(0xFFE28B22),
          'propuso eliminar',
          'ELIMINACIÓN PROPUESTA',
        );
      case 'delete_approved':
        return const _HistoryConfig(
          Icons.delete_forever_outlined,
          Color(0xFFD94E61),
          'eliminó (aprobado)',
          'ELIMINACIÓN APROBADA',
        );
      case 'delete_rejected':
        return const _HistoryConfig(
          Icons.cancel_outlined,
          Color(0xFFD94E61),
          'intentó eliminar (rechazado)',
          'ELIMINACIÓN RECHAZADA',
        );
      case 'deleted_free':
        return const _HistoryConfig(
          Icons.delete_outline_rounded,
          Color(0xFF687C8D),
          'eliminó',
          'GASTO ELIMINADO',
        );
      case 'settlement_requested':
        return const _HistoryConfig(
          Icons.payments_outlined,
          Color(0xFF2457C5),
          'avisó pago en',
          'PAGO INFORMADO',
        );
      case 'settlement_confirmed':
        return const _HistoryConfig(
          Icons.check_circle_outline_rounded,
          Color(0xFF2E9D68),
          'confirmó pago en',
          'PAGO CONFIRMADO',
        );
      case 'settlement_recorded':
        return const _HistoryConfig(
          Icons.receipt_long_rounded,
          Color(0xFF087F8C),
          'registró un pago',
          'PAGO REGISTRADO',
        );
      default:
        return const _HistoryConfig(
          Icons.circle_outlined,
          Color(0xFF687C8D),
          'modificó',
          'ACTIVIDAD',
        );
    }
  }
}

class _HistoryHeader extends StatelessWidget {
  const _HistoryHeader({
    required this.groupName,
    required this.entryCount,
    required this.memberCount,
  });

  final String groupName;
  final int entryCount;
  final int memberCount;

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
          colors: [Color(0xFF286FA8), Color(0xFF55B5C9), Color(0xFF70C7C7)],
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF176B87).withValues(alpha: 0.22),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            right: -36,
            top: -72,
            child: Container(
              width: 178,
              height: 178,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(right: 3, top: 8, child: _HistoryDocumentDecoration()),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.28),
                      ),
                    ),
                    child: const Icon(
                      Icons.history_rounded,
                      color: Colors.white,
                      size: 23,
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Text(
                      'HISTORIAL DEL GRUPO',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.95),
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  const SizedBox(width: 76),
                ],
              ),
              const SizedBox(height: 18),
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
              const SizedBox(height: 7),
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: textWidth),
                child: Text(
                  'Cada cambio importante del grupo, en orden y a la vista.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.93),
                    height: 1.35,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  _HistoryHeaderMetric(
                    icon: Icons.receipt_long_rounded,
                    value: '$entryCount',
                    label: entryCount == 1 ? 'movimiento' : 'movimientos',
                  ),
                  const SizedBox(width: 9),
                  _HistoryHeaderMetric(
                    icon: Icons.groups_rounded,
                    value: '$memberCount',
                    label: memberCount == 1 ? 'integrante' : 'integrantes',
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HistoryDocumentDecoration extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: 0.1,
      child: Container(
        width: 66,
        height: 82,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.receipt_long_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(height: 8),
            ...List.generate(
              3,
              (index) => Container(
                width: index == 2 ? 26 : 40,
                height: 3,
                margin: const EdgeInsets.only(bottom: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryHeaderMetric extends StatelessWidget {
  const _HistoryHeaderMetric({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.17),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 7),
          Text(
            value,
            style: theme.textTheme.labelLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.95),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivitySectionHeading extends StatelessWidget {
  const _ActivitySectionHeading({
    required this.entryCount,
    required this.style,
  });

  final int entryCount;
  final TextTheme style;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF087F8C), Color(0xFF20A6A7)],
            ),
            borderRadius: BorderRadius.circular(13),
          ),
          child: const Icon(
            Icons.timeline_rounded,
            color: Colors.white,
            size: 21,
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Actividad reciente',
                style: style.titleMedium?.copyWith(
                  color: const Color(0xFF173B75),
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                'El recorrido de tu grupo, movimiento por movimiento',
                style: style.bodySmall?.copyWith(
                  color: const Color(0xFF687C8D),
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFDDEFF2),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '$entryCount',
            style: style.labelLarge?.copyWith(
              color: const Color(0xFF087F8C),
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _HistoryTimelineItem extends StatelessWidget {
  const _HistoryTimelineItem({
    required this.entry,
    required this.dateLabel,
    required this.config,
    required this.isLast,
    required this.groupId,
  });

  final HistoryEntry entry;
  final String dateLabel;
  final _HistoryConfig config;
  final bool isLast;
  final String groupId;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 34,
            child: Column(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        config.color,
                        config.color.withValues(alpha: 0.75),
                      ],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: config.color.withValues(alpha: 0.22),
                        blurRadius: 9,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Icon(config.icon, color: Colors.white, size: 18),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 5),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            config.color.withValues(alpha: 0.45),
                            const Color(0xFFDCE8EF),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 13),
              child: _HistoryEntryCard(
                entry: entry,
                dateLabel: dateLabel,
                config: config,
                groupId: groupId,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryEntryCard extends StatelessWidget {
  const _HistoryEntryCard({
    required this.entry,
    required this.dateLabel,
    required this.config,
    required this.groupId,
  });

  final HistoryEntry entry;
  final String dateLabel;
  final _HistoryConfig config;
  final String groupId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final titleColor = const Color(0xFF173B75);
    final details = entry.details?.trim();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: config.color.withValues(alpha: 0.16)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF173B75).withValues(alpha: 0.055),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          children: [
            Container(width: 4, color: config.color),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(13, 13, 13, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 7,
                      runSpacing: 6,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: config.color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            config.label,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: config.color,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                        Text(
                          dateLabel,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: const Color(0xFF8093A1),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 9),
                    if (entry.action == 'settlement_recorded')
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: entry.performedByName,
                              style: TextStyle(
                                color: titleColor,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const TextSpan(
                              text: ' registró que ',
                              style: TextStyle(color: Color(0xFF526879)),
                            ),
                            TextSpan(
                              text: entry.settlementFromName ?? 'Un integrante',
                              style: TextStyle(
                                color: titleColor,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const TextSpan(
                              text: ' pagó a ',
                              style: TextStyle(color: Color(0xFF526879)),
                            ),
                            TextSpan(
                              text: entry.settlementToName ?? 'otro integrante',
                              style: TextStyle(
                                color: titleColor,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (entry.settlementAmount != null)
                              TextSpan(
                                text:
                                    ' ${NumberFormat.currency(locale: 'es_CL', symbol: '\$', decimalDigits: 0).format(entry.settlementAmount)}',
                                style: TextStyle(
                                  color: titleColor,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                          ],
                        ),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          height: 1.35,
                        ),
                      )
                    else
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: entry.performedByName,
                              style: TextStyle(
                                color: titleColor,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            TextSpan(
                              text: ' ${config.verb} ',
                              style: const TextStyle(color: Color(0xFF526879)),
                            ),
                            TextSpan(
                              text: '"${entry.expenseDescription}"',
                              style: TextStyle(
                                color: titleColor,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          height: 1.35,
                        ),
                      ),
                    if (details != null && details.isNotEmpty) ...[
                      const SizedBox(height: 7),
                      Text(
                        details,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF687C8D),
                          height: 1.4,
                        ),
                      ),
                    ],
                    if (entry.hasSettlementReceipt &&
                        entry.settlementId != null) ...[
                      const SizedBox(height: 9),
                      _HistorySettlementReceipt(
                        groupId: groupId,
                        settlementId: entry.settlementId!,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistorySettlementReceipt extends StatefulWidget {
  const _HistorySettlementReceipt({
    required this.groupId,
    required this.settlementId,
  });

  final String groupId;
  final String settlementId;

  @override
  State<_HistorySettlementReceipt> createState() =>
      _HistorySettlementReceiptState();
}

class _HistorySettlementReceiptState extends State<_HistorySettlementReceipt> {
  late Future<SettlementReceipt?> _receiptFuture;

  @override
  void initState() {
    super.initState();
    _loadRecord();
  }

  @override
  void didUpdateWidget(covariant _HistorySettlementReceipt oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.groupId != widget.groupId ||
        oldWidget.settlementId != widget.settlementId) {
      _loadRecord();
    }
  }

  void _loadRecord() {
    _receiptFuture = FirestoreService().getSettlementReceipt(
      groupId: widget.groupId,
      settlementId: widget.settlementId,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<SettlementReceipt?>(
      future: _receiptFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Text(
            'No se pudo cargar el comprobante.',
            style: TextStyle(color: Color(0xFFD94E61), fontSize: 12),
          );
        }
        if (!snapshot.hasData) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SizedBox(
              height: 24,
              width: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            );
          }
          return const SizedBox.shrink();
        }
        final receipt = snapshot.data;
        if (receipt == null) {
          return const Text(
            'El comprobante ya no está disponible.',
            style: TextStyle(color: Color(0xFFD94E61), fontSize: 12),
          );
        }

        Uint8List imageBytes;
        try {
          imageBytes = base64Decode(receipt.imageBase64);
        } on FormatException catch (error) {
          debugPrint(
            'El comprobante de liquidación ${widget.settlementId} no es Base64 válido: $error',
          );
          return const Text(
            'El comprobante guardado no se puede mostrar.',
            style: TextStyle(color: Color(0xFFD94E61), fontSize: 12),
          );
        }

        return OutlinedButton.icon(
          onPressed: () => _openReceipt(context, imageBytes),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF087F8C),
            side: const BorderSide(color: Color(0xFFB7DCE8)),
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(13),
            ),
          ),
          icon: const Icon(Icons.image_search_rounded, size: 18),
          label: const Text('Ver comprobante'),
        );
      },
    );
  }

  void _openReceipt(BuildContext context, Uint8List bytes) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: const Text('Comprobante de pago'),
            leading: IconButton(
              tooltip: 'Cerrar',
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close_rounded),
            ),
          ),
          body: SafeArea(
            child: Center(
              child: InteractiveViewer(
                minScale: 0.8,
                maxScale: 5,
                child: Image.memory(bytes, fit: BoxFit.contain),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HistoryMessage extends StatelessWidget {
  const _HistoryMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.isError = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Card(
            elevation: 1,
            shadowColor: const Color(0xFF173B75).withValues(alpha: 0.06),
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
              side: const BorderSide(color: Color(0xFFDCE8EF)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color:
                          (isError
                                  ? const Color(0xFFD94E61)
                                  : const Color(0xFF087F8C))
                              .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(19),
                    ),
                    child: Icon(
                      icon,
                      size: 29,
                      color: isError
                          ? const Color(0xFFD94E61)
                          : const Color(0xFF087F8C),
                    ),
                  ),
                  const SizedBox(height: 15),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: const Color(0xFF173B75),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF687C8D),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HistoryConfig {
  const _HistoryConfig(this.icon, this.color, this.verb, this.label);

  final IconData icon;
  final Color color;
  final String verb;
  final String label;
}
