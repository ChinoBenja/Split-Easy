import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/group_model.dart';
import '../../models/history_entry_model.dart';
import '../../services/firestore_service.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key, required this.group});

  final GroupModel group;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final firestoreService = FirestoreService();
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
        stream: firestoreService.watchHistory(group.id),
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
                          groupName: group.name,
                          entryCount: entries.length,
                        ),
                        const SizedBox(height: 22),
                        Row(
                          children: [
                            const Icon(
                              Icons.schedule_rounded,
                              size: 18,
                              color: Color(0xFF087F8C),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Actividad reciente',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: const Color(0xFF173B75),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ...entries.map(
                          (entry) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _HistoryEntryCard(
                              entry: entry,
                              dateLabel: dateFormat.format(entry.createdAt),
                              config: _configFor(entry.action),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          );
        },
      ),
    );
  }

  _HistoryConfig _configFor(String action) {
    switch (action) {
      case 'created':
        return const _HistoryConfig(
          Icons.add_circle_outline_rounded,
          Color(0xFF2E9D68),
          'creó',
        );
      case 'edit_proposed':
        return const _HistoryConfig(
          Icons.edit_note_rounded,
          Color(0xFF2457C5),
          'propuso editar',
        );
      case 'edit_approved':
        return const _HistoryConfig(
          Icons.check_circle_outline_rounded,
          Color(0xFF2E9D68),
          'editó (aprobado)',
        );
      case 'edit_rejected':
        return const _HistoryConfig(
          Icons.cancel_outlined,
          Color(0xFFD94E61),
          'intentó editar (rechazado)',
        );
      case 'delete_proposed':
        return const _HistoryConfig(
          Icons.delete_outline_rounded,
          Color(0xFFE28B22),
          'propuso eliminar',
        );
      case 'delete_approved':
        return const _HistoryConfig(
          Icons.delete_forever_outlined,
          Color(0xFFD94E61),
          'eliminó (aprobado)',
        );
      case 'delete_rejected':
        return const _HistoryConfig(
          Icons.cancel_outlined,
          Color(0xFFD94E61),
          'intentó eliminar (rechazado)',
        );
      case 'deleted_free':
        return const _HistoryConfig(
          Icons.delete_outline_rounded,
          Color(0xFF687C8D),
          'eliminó',
        );
      case 'settlement_requested':
        return const _HistoryConfig(
          Icons.payments_outlined,
          Color(0xFF2457C5),
          'avisó pago en',
        );
      case 'settlement_confirmed':
        return const _HistoryConfig(
          Icons.check_circle_outline_rounded,
          Color(0xFF2E9D68),
          'confirmó pago en',
        );
      default:
        return const _HistoryConfig(
          Icons.circle_outlined,
          Color(0xFF687C8D),
          'modificó',
        );
    }
  }
}

class _HistoryHeader extends StatelessWidget {
  const _HistoryHeader({required this.groupName, required this.entryCount});

  final String groupName;
  final int entryCount;

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
            right: -24,
            top: -64,
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
                      Icons.history_rounded,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 11),
                  Text(
                    'HISTORIAL DEL GRUPO',
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
                'Revisa las acciones y movimientos registrados por el grupo.',
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
                      Icons.receipt_long_rounded,
                      size: 15,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 7),
                    Text(
                      '$entryCount ${entryCount == 1 ? 'movimiento' : 'movimientos'}',
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

class _HistoryEntryCard extends StatelessWidget {
  const _HistoryEntryCard({
    required this.entry,
    required this.dateLabel,
    required this.config,
  });

  final HistoryEntry entry;
  final String dateLabel;
  final _HistoryConfig config;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final titleColor = const Color(0xFF173B75);
    final details = entry.details?.trim();

    return Card(
      margin: EdgeInsets.zero,
      elevation: 1,
      shadowColor: const Color(0xFF173B75).withValues(alpha: 0.06),
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFDCE8EF)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: config.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(config.icon, color: config.color, size: 21),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: entry.performedByName,
                          style: TextStyle(
                            color: titleColor,
                            fontWeight: FontWeight.w700,
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
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.3),
                  ),
                  if (details != null && details.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Text(
                      details,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF687C8D),
                        height: 1.35,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.schedule_rounded,
                        size: 14,
                        color: Color(0xFF8093A1),
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          dateLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: const Color(0xFF687C8D),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
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
  const _HistoryConfig(this.icon, this.color, this.verb);

  final IconData icon;
  final Color color;
  final String verb;
}
