import 'dart:async';
import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../models/expense_proposal_model.dart';
import '../../models/group_deletion_proposal_model.dart';
import '../../models/group_model.dart';
import '../../models/message_model.dart';
import '../../services/firestore_service.dart';
import '../widgets/profile_photo_image.dart';

class ChatScreen extends StatefulWidget {
  final GroupModel group;
  const ChatScreen({super.key, required this.group});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _firestoreService = FirestoreService();
  final _messageController = TextEditingController();
  late final Future<Map<String, String>> _memberPhotoUrls;
  late final Stream<List<ChatMessage>> _messagesStream;
  StreamSubscription<List<ChatMessage>>? _readReceiptSubscription;
  bool _isSending = false;
  bool _isPickingImage = false;
  bool _isUploadingImage = false;

  @override
  void initState() {
    super.initState();
    _memberPhotoUrls = _firestoreService.getUserPhotoUrls(
      widget.group.memberIds,
    );
    _messagesStream = _firestoreService.watchMessages(widget.group.id);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      unawaited(_markMessagesRead(uid));
      // Al entrar y al llegar mensajes nuevos, actualiza el estado de lectura.
      _readReceiptSubscription = _messagesStream.listen(
        (_) => unawaited(_markMessagesRead(uid)),
        onError: (Object error, StackTrace stackTrace) {
          debugPrint('No se pudo actualizar la lectura del chat: $error');
          debugPrintStack(stackTrace: stackTrace);
        },
      );
    }
  }

  Future<void> _markMessagesRead(String uid) async {
    try {
      await _firestoreService.markGroupMessagesRead(
        groupId: widget.group.id,
        uid: uid,
      );
    } catch (error, stackTrace) {
      debugPrint('No se pudo actualizar la lectura del chat: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  @override
  void dispose() {
    unawaited(_readReceiptSubscription?.cancel() ?? Future<void>.value());
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (_isSending || text.isEmpty) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inicia sesión para enviar mensajes.')),
      );
      return;
    }

    setState(() => _isSending = true);
    try {
      await _firestoreService.sendTextMessage(
        groupId: widget.group.id,
        senderId: user.uid,
        senderName:
            widget.group.memberNames[user.uid] ??
            user.displayName ??
            user.email ??
            'Usuario',
        text: text,
        senderPhotoUrl: user.photoURL,
      );
      if (!mounted) return;
      _messageController.clear();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo enviar el mensaje: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _pickAndSendImage() async {
    if (_isSending) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inicia sesión para enviar imágenes.')),
      );
      return;
    }

    setState(() {
      _isSending = true;
      _isPickingImage = true;
    });
    try {
      final image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
      if (!mounted) return;
      if (image == null) return;

      if (mounted) {
        setState(() {
          _isPickingImage = false;
          _isUploadingImage = true;
        });
      }
      final extension = image.name.contains('.')
          ? image.name.split('.').last.toLowerCase()
          : 'jpg';
      final safeExtension = RegExp(r'^[a-z0-9]+$').hasMatch(extension)
          ? extension
          : 'jpg';
      final contentType = image.mimeType?.startsWith('image/') == true
          ? image.mimeType!
          : 'image/$safeExtension';
      final storageRef = FirebaseStorage.instance.ref().child(
        'chat_images/${widget.group.id}/${DateTime.now().microsecondsSinceEpoch}_${user.uid}.$safeExtension',
      );
      final bytes = await image.readAsBytes();
      if (!mounted) return;
      if (bytes.length > 10 * 1024 * 1024) {
        throw StateError('La imagen no puede superar los 10 MB.');
      }
      await storageRef.putData(
        bytes,
        SettableMetadata(contentType: contentType),
      );
      if (!mounted) return;
      final imageUrl = await storageRef.getDownloadURL();
      if (!mounted) return;

      await _firestoreService.sendTextMessage(
        groupId: widget.group.id,
        senderId: user.uid,
        senderName:
            widget.group.memberNames[user.uid] ??
            user.displayName ??
            user.email ??
            'Usuario',
        text: _messageController.text.trim(),
        imageUrl: imageUrl,
        senderPhotoUrl: user.photoURL,
      );
      if (!mounted) return;
      _messageController.clear();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo enviar la imagen: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
          _isPickingImage = false;
          _isUploadingImage = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFEAF4FB),
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFFE7F3F8),
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Icon(
                Icons.forum_rounded,
                color: Color(0xFF087F8C),
                size: 20,
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.group.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: const Color(0xFF173B75),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'Chat del grupo',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: const Color(0xFF687C8D),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFFEAF4FB),
        foregroundColor: const Color(0xFF173B75),
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              stream: _messagesStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'No se pudieron cargar los mensajes: ${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFFD94E61),
                        ),
                      ),
                    ),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFF2457C5)),
                  );
                }
                final messages = snapshot.data!;
                if (messages.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 340),
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: const Color(0xFFDCE8EF)),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFF173B75,
                              ).withValues(alpha: 0.05),
                              blurRadius: 16,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: const Color(0xFFE7F3F8),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: const Icon(
                                Icons.forum_outlined,
                                color: Color(0xFF087F8C),
                                size: 28,
                              ),
                            ),
                            const SizedBox(height: 13),
                            Text(
                              'Aún no hay mensajes',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: const Color(0xFF173B75),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              'Inicia la conversación con tu grupo.',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: const Color(0xFF687C8D),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }

                return FutureBuilder<Map<String, String>>(
                  future: _memberPhotoUrls,
                  builder: (context, photoSnapshot) {
                    final photoUrls =
                        photoSnapshot.data ?? const <String, String>{};
                    return ListView.builder(
                      reverse: true,
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final message = messages[index];
                        final isMine = message.senderId == currentUid;

                        if (message.type == 'system') {
                          return _SystemMessageBubble(message: message);
                        }
                        if (message.type == 'proposal') {
                          return _ProposalCard(
                            group: widget.group,
                            message: message,
                            currentUid: currentUid,
                          );
                        }
                        if (message.type == 'group_delete_proposal') {
                          return _GroupDeletionProposalCard(
                            group: widget.group,
                            message: message,
                            currentUid: currentUid,
                          );
                        }
                        if (message.type == 'settlement_request') {
                          return _SettlementRequestBubble(message: message);
                        }
                        final storedPhotoUrl = message.senderPhotoUrl?.trim();
                        return _TextMessageBubble(
                          message: message,
                          isMine: isMine,
                          photoUrl:
                              photoUrls[message.senderId] ??
                              (storedPhotoUrl == null || storedPhotoUrl.isEmpty
                                  ? null
                                  : storedPhotoUrl),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: const Border(top: BorderSide(color: Color(0xFFDCE8EF))),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF173B75).withValues(alpha: 0.05),
                    blurRadius: 12,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isSending)
                    Column(
                      children: [
                        const LinearProgressIndicator(
                          minHeight: 2,
                          color: Color(0xFF2457C5),
                          backgroundColor: Color(0xFFE7F3F8),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 5),
                          child: Text(
                            _isPickingImage
                                ? 'Seleccionando imagen...'
                                : _isUploadingImage
                                ? 'Enviando imagen...'
                                : 'Enviando mensaje...',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: const Color(0xFF687C8D),
                            ),
                          ),
                        ),
                      ],
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 9, 12, 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _messageController,
                            textCapitalization: TextCapitalization.sentences,
                            minLines: 1,
                            maxLines: 5,
                            decoration: InputDecoration(
                              hintText: 'Escribe un mensaje...',
                              hintStyle: const TextStyle(
                                color: Color(0xFF687C8D),
                              ),
                              filled: true,
                              fillColor: const Color(0xFFEAF4FB),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: const BorderSide(
                                  color: Color(0xFF54A6C7),
                                  width: 1.3,
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 17,
                                vertical: 12,
                              ),
                            ),
                            onSubmitted: (_) => _sendMessage(),
                          ),
                        ),
                        const SizedBox(width: 5),
                        IconButton(
                          onPressed: _isSending ? null : _pickAndSendImage,
                          tooltip: 'Adjuntar imagen',
                          style: IconButton.styleFrom(
                            foregroundColor: const Color(0xFF173B75),
                          ),
                          icon: const Icon(Icons.image_outlined),
                        ),
                        const SizedBox(width: 2),
                        IconButton.filled(
                          onPressed: _isSending ? null : _sendMessage,
                          style: IconButton.styleFrom(
                            backgroundColor: const Color(0xFF2457C5),
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.send_rounded),
                        ),
                      ],
                    ),
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
  final String? photoUrl;

  const _TextMessageBubble({
    required this.message,
    required this.isMine,
    required this.photoUrl,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foregroundColor = isMine ? Colors.white : const Color(0xFF173B75);

    final imageUrl = message.imageUrl?.trim();
    final bubble = Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * 0.68,
      ),
      decoration: BoxDecoration(
        gradient: isMine
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF2457C5), Color(0xFF087F8C)],
              )
            : null,
        color: isMine ? null : Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(18),
          topRight: const Radius.circular(18),
          bottomLeft: Radius.circular(isMine ? 18 : 6),
          bottomRight: Radius.circular(isMine ? 6 : 18),
        ),
        border: isMine ? null : Border.all(color: const Color(0xFFDCE8EF)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF173B75).withValues(alpha: 0.06),
            blurRadius: 9,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message.senderName,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: isMine
                  ? Colors.white.withValues(alpha: 0.82)
                  : const Color(0xFF087F8C),
            ),
          ),
          if (imageUrl != null && imageUrl.isNotEmpty) ...[
            const SizedBox(height: 6),
            GestureDetector(
              onTap: () => _previewImage(context, imageUrl),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  imageUrl,
                  width: math.min(
                    280.0,
                    MediaQuery.sizeOf(context).width * 0.62,
                  ),
                  height: 220,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return const SizedBox(
                      width: 220,
                      height: 180,
                      child: Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF2457C5),
                        ),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) => const SizedBox(
                    width: 220,
                    height: 180,
                    child: Center(child: Icon(Icons.broken_image_outlined)),
                  ),
                ),
              ),
            ),
          ],
          if (message.text?.trim().isNotEmpty == true) ...[
            if (imageUrl != null && imageUrl.isNotEmpty)
              const SizedBox(height: 6),
            Text(
              message.text!,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: foregroundColor,
                height: 1.35,
              ),
            ),
          ],
          Align(
            alignment: Alignment.bottomRight,
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                DateFormat('HH:mm').format(message.createdAt),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: isMine
                      ? Colors.white.withValues(alpha: 0.76)
                      : const Color(0xFF8093A1),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: isMine
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          if (!isMine) ...[
            _SenderAvatar(name: message.senderName, photoUrl: photoUrl),
            const SizedBox(width: 8),
          ],
          Flexible(child: bubble),
          if (isMine) ...[
            const SizedBox(width: 8),
            _SenderAvatar(name: message.senderName, photoUrl: photoUrl),
          ],
        ],
      ),
    );
  }

  void _previewImage(BuildContext context, String imageUrl) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.9,
            maxHeight: MediaQuery.sizeOf(context).height * 0.8,
          ),
          child: InteractiveViewer(
            child: Image.network(
              imageUrl,
              fit: BoxFit.contain,
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return const SizedBox(
                  height: 300,
                  child: Center(
                    child: CircularProgressIndicator(color: Color(0xFF2457C5)),
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) => const SizedBox(
                height: 300,
                child: Center(child: Icon(Icons.broken_image_outlined)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SenderAvatar extends StatelessWidget {
  const _SenderAvatar({required this.name, required this.photoUrl});

  final String name;
  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    final initials = name.trim().isEmpty
        ? '?'
        : name.trim().characters.first.toUpperCase();
    final url = photoUrl?.trim();

    return CircleAvatar(
      radius: 16,
      backgroundColor: const Color(0xFFD9EDF4),
      child: url == null || url.isEmpty
          ? Text(
              initials,
              style: const TextStyle(
                color: Color(0xFF087F8C),
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            )
          : ClipOval(
              child: SizedBox.expand(
                child: ProfilePhotoImage(
                  source: url,
                  fallback: Center(
                    child: Text(
                      initials,
                      style: const TextStyle(
                        color: Color(0xFF087F8C),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  fit: BoxFit.cover,
                ),
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
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Center(
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.88,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFDCE8EF)),
          ),
          child: Text(
            message.text ?? '',
            textAlign: TextAlign.center,
            style: theme.textTheme.labelSmall?.copyWith(
              color: const Color(0xFF687C8D),
              height: 1.35,
            ),
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
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Center(
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.88,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
          decoration: BoxDecoration(
            color: const Color(0xFFE7F3F8),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFD2E7EF)),
          ),
          child: Text(
            '💵 ${message.senderName} avisó que pagó su cuota de "${message.expenseDescription ?? 'un gasto'}"',
            textAlign: TextAlign.center,
            style: theme.textTheme.labelSmall?.copyWith(
              color: const Color(0xFF176B87),
              height: 1.35,
            ),
          ),
        ),
      ),
    );
  }
}

class _GroupDeletionProposalCard extends StatefulWidget {
  const _GroupDeletionProposalCard({
    required this.group,
    required this.message,
    required this.currentUid,
  });

  final GroupModel group;
  final ChatMessage message;
  final String? currentUid;

  @override
  State<_GroupDeletionProposalCard> createState() =>
      _GroupDeletionProposalCardState();
}

class _GroupDeletionProposalCardState
    extends State<_GroupDeletionProposalCard> {
  final _firestoreService = FirestoreService();
  bool _isResponding = false;
  bool _isNavigatingToGroups = false;

  void _navigateToGroups() {
    if (!mounted || _isNavigatingToGroups) return;
    _isNavigatingToGroups = true;
    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
  }

  void _scheduleNavigationToGroups() {
    if (_isNavigatingToGroups) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _navigateToGroups();
    });
  }

  Future<void> _respond(GroupDeletionProposal proposal, String response) async {
    final uid = widget.currentUid;
    if (uid == null || _isResponding) return;

    setState(() => _isResponding = true);
    try {
      final status = await _firestoreService.respondToGroupDeletionProposal(
        groupId: widget.group.id,
        proposalId: proposal.id,
        uid: uid,
        response: response,
      );
      if (!mounted) return;

      if (status == 'approved') {
        _navigateToGroups();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              status == 'rejected'
                  ? 'La eliminación del grupo fue rechazada.'
                  : response == 'accepted'
                  ? 'Tu aceptación fue registrada.'
                  : 'Tu rechazo fue registrado.',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo registrar el voto: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _isResponding = false);
    }
  }

  String _memberName(String uid) =>
      widget.group.memberNames[uid] ?? 'Integrante';

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final proposalId = widget.message.proposalId;
    if (proposalId == null) return const SizedBox.shrink();

    return StreamBuilder<GroupDeletionProposal?>(
      stream: _firestoreService.watchGroupDeletionProposal(
        widget.group.id,
        proposalId,
      ),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Card(
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(color: colors.error.withValues(alpha: 0.3)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Text(
                'No se pudo cargar la votación: ${snapshot.error}',
                style: TextStyle(color: colors.error),
              ),
            ),
          );
        }
        final proposal = snapshot.data;
        if (proposal == null) {
          if (snapshot.connectionState == ConnectionState.active &&
              !snapshot.hasError) {
            _scheduleNavigationToGroups();
          }
          return const SizedBox.shrink();
        }
        if (proposal.status == 'approved') {
          _scheduleNavigationToGroups();
        }

        final accepted = widget.group.memberIds
            .where((uid) => proposal.responses[uid] == 'accepted')
            .map(_memberName)
            .toList();
        final rejected = widget.group.memberIds
            .where((uid) => proposal.responses[uid] == 'rejected')
            .map(_memberName)
            .toList();
        final pending = proposal.pendingMembers(widget.group.memberIds);
        final canRespond =
            proposal.status == 'pending' &&
            widget.currentUid != null &&
            !proposal.hasResponded(widget.currentUid!);
        final statusColor = proposal.status == 'approved'
            ? const Color(0xFF2E9D68)
            : proposal.status == 'rejected'
            ? const Color(0xFFD94E61)
            : const Color(0xFFE28B22);

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8),
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: colors.error.withValues(alpha: 0.25)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.delete_sweep_outlined, color: colors.error),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${proposal.proposedByName} propuso eliminar el grupo',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: const Color(0xFF173B75),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (accepted.isNotEmpty)
                  _voteStatus(
                    Icons.check_circle_outline_rounded,
                    'Aceptaron: ${accepted.join(', ')}',
                    colors.primary,
                  ),
                if (rejected.isNotEmpty)
                  _voteStatus(
                    Icons.cancel_outlined,
                    'Rechazaron: ${rejected.join(', ')}',
                    colors.error,
                  ),
                if (pending.isNotEmpty)
                  _voteStatus(
                    Icons.schedule_rounded,
                    'Pendientes: ${pending.map(_memberName).join(', ')}',
                    colors.onSurfaceVariant,
                  ),
                const SizedBox(height: 8),
                Text(
                  proposal.status == 'approved'
                      ? 'Consenso alcanzado. Eliminando grupo…'
                      : proposal.status == 'rejected'
                      ? 'La propuesta fue rechazada.'
                      : 'El grupo se eliminará si todos aceptan.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (canRespond) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isResponding
                              ? null
                              : () => _respond(proposal, 'rejected'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFD94E61),
                            side: const BorderSide(color: Color(0xFFD94E61)),
                            shape: const StadiumBorder(),
                          ),
                          child: const Text('Rechazar'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: _isResponding
                              ? null
                              : () => _respond(proposal, 'accepted'),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF2457C5),
                            foregroundColor: Colors.white,
                            shape: const StadiumBorder(),
                          ),
                          child: _isResponding
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Aceptar'),
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

  Widget _voteStatus(IconData icon, String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(top: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: color),
          const SizedBox(width: 7),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

/// Tarjeta de propuesta de edición O eliminación, según proposal.type.
class _ProposalCard extends StatelessWidget {
  final GroupModel group;
  final ChatMessage message;
  final String? currentUid;

  const _ProposalCard({
    required this.group,
    required this.message,
    required this.currentUid,
  });

  @override
  Widget build(BuildContext context) {
    final firestoreService = FirestoreService();
    final currencyFormat = NumberFormat.currency(
      locale: 'es_CL',
      symbol: '\$',
      decimalDigits: 0,
    );

    if (message.expenseId == null || message.proposalId == null) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<ExpenseProposal?>(
      stream: firestoreService.watchProposal(
        group.id,
        message.expenseId!,
        message.proposalId!,
      ),
      builder: (context, snapshot) {
        final proposal = snapshot.data;
        if (proposal == null) return const SizedBox.shrink();

        final isDelete = proposal.type == 'delete';
        final hasResponded =
            currentUid != null && proposal.hasResponded(currentUid!);
        final pending = proposal.pendingMembers(group.memberIds);

        Color statusColor;
        String statusText;
        switch (proposal.status) {
          case 'approved':
            statusColor = const Color(0xFF2E9D68);
            statusText = isDelete ? '✅ Gasto eliminado' : '✅ Cambio aplicado';
            break;
          case 'rejected':
            statusColor = const Color(0xFFD94E61);
            statusText = isDelete
                ? '❌ Eliminación rechazada'
                : '❌ Cambio rechazado';
            break;
          default:
            statusColor = const Color(0xFFE28B22);
            statusText = pending.isEmpty
                ? 'Pendiente'
                : 'Esperando: ${pending.map((id) => group.memberNames[id] ?? '').join(', ')}';
        }

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8),
          color: Colors.white,
          elevation: 1,
          shadowColor: const Color(0xFF173B75).withValues(alpha: 0.06),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color:
                  (isDelete ? const Color(0xFFD94E61) : const Color(0xFF54A6C7))
                      .withValues(alpha: 0.28),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      isDelete
                          ? Icons.delete_outline_rounded
                          : Icons.edit_note_rounded,
                      size: 20,
                      color: isDelete
                          ? const Color(0xFFD94E61)
                          : const Color(0xFF087F8C),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        isDelete
                            ? '${proposal.proposedByName} propuso ELIMINAR un gasto'
                            : '${proposal.proposedByName} propuso un cambio',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: const Color(0xFF173B75),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (isDelete)
                  Text(
                    '"${proposal.oldValues['description'] ?? ''}" · ${currencyFormat.format((proposal.oldValues['amount'] as num?)?.toDouble() ?? 0)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF526879),
                    ),
                  )
                else
                  ..._buildDiffLines(proposal, currencyFormat),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (proposal.status == 'pending' && !hasResponded) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _respond(
                            context,
                            firestoreService,
                            proposal,
                            'rejected',
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFD94E61),
                            side: const BorderSide(color: Color(0xFFD94E61)),
                            shape: const StadiumBorder(),
                          ),
                          child: const Text('Rechazar'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => _respond(
                            context,
                            firestoreService,
                            proposal,
                            'accepted',
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF2457C5),
                            foregroundColor: Colors.white,
                            shape: const StadiumBorder(),
                          ),
                          child: Text(
                            isDelete ? 'Aceptar eliminación' : 'Aceptar',
                          ),
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

  List<Widget> _buildDiffLines(
    ExpenseProposal proposal,
    NumberFormat currencyFormat,
  ) {
    final lines = <Widget>[];
    final old = proposal.oldValues;
    final updated = proposal.newValues;

    if (old['description'] != updated['description']) {
      lines.add(
        _diffText('Descripción', old['description'], updated['description']),
      );
    }
    if (old['amount'] != updated['amount']) {
      lines.add(
        _diffText(
          'Monto',
          currencyFormat.format((old['amount'] as num).toDouble()),
          currencyFormat.format((updated['amount'] as num).toDouble()),
        ),
      );
    }
    if (old['category'] != updated['category']) {
      lines.add(_diffText('Categoría', old['category'], updated['category']));
    }
    lines.add(
      const Padding(
        padding: EdgeInsets.only(top: 4),
        child: Text(
          'Revisa el detalle del gasto para ver los pagadores y participantes actualizados.',
          style: TextStyle(fontSize: 11, color: Color(0xFF687C8D)),
        ),
      ),
    );

    return lines;
  }

  Widget _diffText(String label, dynamic oldValue, dynamic newValue) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 13, color: Color(0xFF526879)),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            TextSpan(
              text: '$oldValue',
              style: const TextStyle(
                decoration: TextDecoration.lineThrough,
                color: Color(0xFF8093A1),
              ),
            ),
            const TextSpan(text: '  →  '),
            TextSpan(
              text: '$newValue',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF2457C5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _respond(
    BuildContext context,
    FirestoreService service,
    ExpenseProposal proposal,
    String response,
  ) async {
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
      if (!context.mounted) return;

      final myName = group.memberNames[currentUid] ?? 'Alguien';
      final isDelete = proposal.type == 'delete';
      if (finalStatus == 'approved') {
        await service.sendSystemMessage(
          groupId: group.id,
          text: isDelete
              ? '✅ Todos aceptaron eliminar el gasto propuesto por ${proposal.proposedByName}.'
              : '✅ Todos aceptaron el cambio propuesto por ${proposal.proposedByName}. El gasto fue actualizado.',
        );
        if (!context.mounted) return;
        await service.notifyBalanceUpdate(group);
      } else if (finalStatus == 'rejected') {
        await service.sendSystemMessage(
          groupId: group.id,
          text:
              '❌ $myName rechazó ${isDelete ? 'la eliminación' : 'el cambio'} propuesto por ${proposal.proposedByName}.',
        );
      } else {
        await service.sendSystemMessage(
          groupId: group.id,
          text:
              '$myName aceptó ${isDelete ? 'la eliminación' : 'el cambio'} propuesto por ${proposal.proposedByName}.',
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('No se pudo responder: $e')));
      }
    }
  }
}
