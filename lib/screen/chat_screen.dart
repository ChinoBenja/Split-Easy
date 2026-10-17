import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/expense_proposal_model.dart';
import '../../models/group_model.dart';
import '../../models/message_model.dart';
import '../../services/firestore_service.dart';

class ChatScreen extends StatefulWidget {
  final GroupModel group;
  const ChatScreen({super.key, required this.group});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _firestoreService = FirestoreService();
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isSending = false;

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isSending = true);
    try {
      await _firestoreService.sendTextMessage(
        groupId: widget.group.id,
        senderId: user.uid,
        senderName: widget.group.memberNames[user.uid] ?? 'Usuario',
        text: text,
      );
      _messageController.clear();
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(title: Text('Chat · ${widget.group.name}')),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              stream: _firestoreService.watchMessages(widget.group.id),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final messages = snapshot.data!;
                if (messages.isEmpty) {
                  return Center(
                    child: Text(
                      'Aún no hay mensajes.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  );
                }

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scrollController.hasClients) {
                    _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
                  }
                });

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(12),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isMine = message.senderId == currentUid;

                    if (message.type == 'system') {
                      return _SystemMessageBubble(message: message);
                    }
                    if (message.type == 'proposal') {
                      return _ProposalCard(group: widget.group, message: message, currentUid: currentUid);
                    }
                    if (message.type == 'settlement_request') {
                      return _SettlementRequestBubble(message: message);
                    }
                    return _TextMessageBubble(message: message, isMine: isMine);
                  },
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: 'Escribe un mensaje...',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _isSending ? null : _sendMessage,
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TextMessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMine;
  const _TextMessageBubble({required this.message, required this.isMine});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isMine ? Theme.of(context).colorScheme.primary : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMine)
              Text(message.senderName,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
            Text(message.text ?? '', style: TextStyle(color: isMine ? Colors.white : Colors.black87)),
            Text(DateFormat('HH:mm').format(message.createdAt),
                style: TextStyle(fontSize: 10, color: isMine ? Colors.white70 : Colors.grey.shade500)),
          ],
        ),
      ),
    );
  }
}

class _SystemMessageBubble extends StatelessWidget {
  final ChatMessage message;
  const _SystemMessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
          child: Text(
            message.text ?? '',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          ),
        ),
      ),
    );
  }
}

class _SettlementRequestBubble extends StatelessWidget {
  final ChatMessage message;
  const _SettlementRequestBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(10)),
          child: Text(
            '💵 ${message.senderName} avisó que pagó su cuota de "${message.expenseDescription ?? 'un gasto'}"',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.blue.shade800),
          ),
        ),
      ),
    );
  }
}

/// Tarjeta de propuesta de edición O eliminación, según proposal.type.
class _ProposalCard extends StatelessWidget {
  final GroupModel group;
  final ChatMessage message;
  final String? currentUid;

  const _ProposalCard({required this.group, required this.message, required this.currentUid});

  @override
  Widget build(BuildContext context) {
    final firestoreService = FirestoreService();
    final currencyFormat = NumberFormat.currency(locale: 'es_CL', symbol: '\$', decimalDigits: 0);

    if (message.expenseId == null || message.proposalId == null) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<ExpenseProposal?>(
      stream: firestoreService.watchProposal(group.id, message.expenseId!, message.proposalId!),
      builder: (context, snapshot) {
        final proposal = snapshot.data;
        if (proposal == null) return const SizedBox.shrink();

        final isDelete = proposal.type == 'delete';
        final hasResponded = currentUid != null && proposal.hasResponded(currentUid!);
        final pending = proposal.pendingMembers(group.memberIds);

        Color statusColor;
        String statusText;
        switch (proposal.status) {
          case 'approved':
            statusColor = Colors.green;
            statusText = isDelete ? '✅ Gasto eliminado' : '✅ Cambio aplicado';
            break;
          case 'rejected':
            statusColor = Colors.red;
            statusText = isDelete ? '❌ Eliminación rechazada' : '❌ Cambio rechazado';
            break;
          default:
            statusColor = Colors.orange;
            statusText = pending.isEmpty
                ? 'Pendiente'
                : 'Esperando: ${pending.map((id) => group.memberNames[id] ?? '').join(', ')}';
        }

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8),
          color: isDelete ? Colors.red.shade50 : Colors.blue.shade50,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(isDelete ? Icons.delete_outline : Icons.edit_note,
                        size: 20, color: isDelete ? Colors.red : Colors.blueGrey),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        isDelete
                            ? '${proposal.proposedByName} propuso ELIMINAR un gasto'
                            : '${proposal.proposedByName} propuso un cambio',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (isDelete)
                  Text(
                    '"${proposal.oldValues['description'] ?? ''}" · ${currencyFormat.format((proposal.oldValues['amount'] as num?)?.toDouble() ?? 0)}',
                    style: const TextStyle(fontSize: 13),
                  )
                else
                  ..._buildDiffLines(proposal, currencyFormat),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                  child: Text(statusText,
                      style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
                if (proposal.status == 'pending' && !hasResponded) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _respond(context, firestoreService, proposal, 'rejected'),
                          child: const Text('Rechazar'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => _respond(context, firestoreService, proposal, 'accepted'),
                          child: Text(isDelete ? 'Aceptar eliminación' : 'Aceptar'),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildDiffLines(ExpenseProposal proposal, NumberFormat currencyFormat) {
    final lines = <Widget>[];
    final old = proposal.oldValues;
    final updated = proposal.newValues;

    if (old['description'] != updated['description']) {
      lines.add(_diffText('Descripción', old['description'], updated['description']));
    }
    if (old['amount'] != updated['amount']) {
      lines.add(_diffText(
        'Monto',
        currencyFormat.format((old['amount'] as num).toDouble()),
        currencyFormat.format((updated['amount'] as num).toDouble()),
      ));
    }
    if (old['category'] != updated['category']) {
      lines.add(_diffText('Categoría', old['category'], updated['category']));
    }
    lines.add(const Padding(
      padding: EdgeInsets.only(top: 4),
      child: Text(
        'Revisa el detalle del gasto para ver los pagadores y participantes actualizados.',
        style: TextStyle(fontSize: 11, color: Colors.black54),
      ),
    ));

    return lines;
  }

  Widget _diffText(String label, dynamic oldValue, dynamic newValue) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 13, color: Colors.black87),
          children: [
            TextSpan(text: '$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
            TextSpan(text: '$oldValue', style: const TextStyle(decoration: TextDecoration.lineThrough, color: Colors.black45)),
            const TextSpan(text: '  →  '),
            TextSpan(text: '$newValue', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
          ],
        ),
      ),
    );
  }

  Future<void> _respond(BuildContext context, FirestoreService service, ExpenseProposal proposal, String response) async {
    if (currentUid == null) return;
    try {
      final finalStatus = await service.respondToProposal(
        groupId: group.id,
        expenseId: proposal.expenseId,
        proposalId: proposal.id,
        uid: currentUid!,
        response: response,
        groupMemberIds: group.memberIds,
      );

      final myName = group.memberNames[currentUid] ?? 'Alguien';
      final isDelete = proposal.type == 'delete';
      if (finalStatus == 'approved') {
        await service.sendSystemMessage(
          groupId: group.id,
          text: isDelete
              ? '✅ Todos aceptaron eliminar el gasto propuesto por ${proposal.proposedByName}.'
              : '✅ Todos aceptaron el cambio propuesto por ${proposal.proposedByName}. El gasto fue actualizado.',
        );
        await service.notifyBalanceUpdate(group);
      } else if (finalStatus == 'rejected') {
        await service.sendSystemMessage(
          groupId: group.id,
          text: '❌ $myName rechazó ${isDelete ? 'la eliminación' : 'el cambio'} propuesto por ${proposal.proposedByName}.',
        );
      } else {
        await service.sendSystemMessage(
          groupId: group.id,
          text: '$myName aceptó ${isDelete ? 'la eliminación' : 'el cambio'} propuesto por ${proposal.proposedByName}.',
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo responder: $e')));
      }
    }
  }
}
