import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
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
  bool _isSendingImage = false;
  String _imageSendStatus = 'Enviando comprobante...';

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
    if (_supportsLostImageRecovery) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_restoreLostChatImage());
      });
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
      final picker = ImagePicker();
      var image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 75,
      );
      if (!mounted) return;
      if (image == null && _supportsLostImageRecovery) {
        final lostData = await picker.retrieveLostData();
        if (!mounted) return;
        if (lostData.exception != null) throw lostData.exception!;
        image = lostData.files?.firstOrNull;
      }
      if (image == null) return;

      setState(() {
        _isPickingImage = false;
        _isSendingImage = true;
        _imageSendStatus = 'Comprimiendo comprobante...';
      });
      await _compressAndSendImage(image, user);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'No se pudo enviar el comprobante: ${_errorMessage(error)}',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
          _isPickingImage = false;
          _isSendingImage = false;
        });
      }
    }
  }

  bool get _supportsLostImageRecovery =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<void> _restoreLostChatImage() async {
    if (!mounted) return;
    try {
      final lostData = await ImagePicker().retrieveLostData();
      if (!mounted || lostData.isEmpty) return;
      if (lostData.exception != null) throw lostData.exception!;
      final image = lostData.files?.firstOrNull;
      if (image == null) {
        throw StateError('No se pudo recuperar la imagen seleccionada.');
      }

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw StateError('Inicia sesión para enviar imágenes.');
      }
      setState(() {
        _isSending = true;
        _isPickingImage = false;
        _isSendingImage = true;
        _imageSendStatus = 'Comprimiendo comprobante...';
      });
      await _compressAndSendImage(image, user);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'No se pudo recuperar el comprobante: ${_errorMessage(error)}',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
          _isPickingImage = false;
          _isSendingImage = false;
        });
      }
    }
  }

  String _errorMessage(Object error) {
    if (error is StateError) return error.message.toString();
    if (error is ArgumentError) return error.message?.toString() ?? '$error';
    return '$error';
  }

  Future<void> _compressAndSendImage(XFile image, User user) async {
    final bytes = await image.readAsBytes().timeout(
      const Duration(seconds: 30),
      onTimeout: () =>
          throw TimeoutException('No se pudo leer la imagen del dispositivo.'),
    );
    if (!mounted) return;
    final imageBase64 = base64Encode(bytes);
    if (imageBase64.length > FirestoreService.maxChatImageBase64Length) {
      throw StateError(
        'El comprobante comprimido supera los 700 KB permitidos. '
        'Recórtalo o selecciona una imagen más liviana.',
      );
    }
    final contentType = image.mimeType?.startsWith('image/') == true
        ? image.mimeType!
        : 'image/jpeg';
    setState(() => _imageSendStatus = 'Guardando comprobante en el chat...');
    await _firestoreService
        .sendImageMessage(
          groupId: widget.group.id,
          senderId: user.uid,
          senderName:
              widget.group.memberNames[user.uid] ??
              user.displayName ??
              user.email ??
              'Usuario',
          imageBase64: imageBase64,
          imageContentType: contentType,
          text: _messageController.text.trim(),
          senderPhotoUrl: user.photoURL,
        )
        .timeout(
          const Duration(seconds: 30),
          onTimeout: () => throw TimeoutException(
            'Firestore no respondió al publicar la imagen en el chat.',
          ),
        );
    if (!mounted) return;
    _messageController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFEAF4FB),
      appBar: AppBar(
        toolbarHeight: 76,
        titleSpacing: 0,
        title: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.3),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.75),
                  width: 1.5,
                ),
              ),
              child: ClipOval(
                child: widget.group.photoSource == null
                    ? Container(
                        color: Colors.white.withValues(alpha: 0.18),
                        child: const Icon(
                          Icons.groups_rounded,
                          color: Colors.white,
                          size: 25,
                        ),
                      )
                    : ProfilePhotoImage(
                        source: widget.group.photoSource!,
                        fallback: Container(
                          color: Colors.white.withValues(alpha: 0.18),
                          child: const Icon(
                            Icons.groups_rounded,
                            color: Colors.white,
                            size: 25,
                          ),
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 12),
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
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      const Icon(
                        Icons.people_alt_rounded,
                        color: Color(0xFFC9F4F1),
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${widget.group.memberIds.length} integrantes · chat grupal',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.88),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
              ),
              child: const Icon(
                Icons.forum_rounded,
                color: Colors.white,
                size: 19,
              ),
            ),
            const SizedBox(width: 12),
          ],
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF173B75), Color(0xFF2457C5), Color(0xFF087F8C)],
            ),
          ),
        ),
        backgroundColor: const Color(0xFF173B75),
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: Column(
        children: [
          Expanded(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFF4F9FC), Color(0xFFEAF4FB)],
                ),
              ),
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
                      child: CircularProgressIndicator(
                        color: Color(0xFF2457C5),
                      ),
                    );
                  }
                  final messages = snapshot.data!;
                  if (messages.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 350),
                          padding: const EdgeInsets.fromLTRB(24, 25, 24, 23),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Colors.white, Color(0xFFF4FAFD)],
                            ),
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(color: const Color(0xFFD9E9F0)),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xFF173B75,
                                ).withValues(alpha: 0.1),
                                blurRadius: 24,
                                offset: const Offset(0, 9),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 82,
                                height: 82,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: const LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Color(0xFF2457C5),
                                      Color(0xFF087F8C),
                                    ],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(
                                        0xFF2457C5,
                                      ).withValues(alpha: 0.22),
                                      blurRadius: 15,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.forum_rounded,
                                  color: Colors.white,
                                  size: 37,
                                ),
                              ),
                              const SizedBox(height: 17),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 11,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE7F3F8),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  'UN NUEVO COMIENZO',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: const Color(0xFF087F8C),
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.65,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 11),
                              Text(
                                'Aún no hay mensajes',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.titleLarge?.copyWith(
                                  color: const Color(0xFF173B75),
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 7),
                              Text(
                                'Saluda al grupo, comparte un gasto o envía un comprobante para empezar.',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: const Color(0xFF687C8D),
                                  height: 1.45,
                                ),
                              ),
                              const SizedBox(height: 17),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _ChatHintChip(
                                    icon: Icons.chat_bubble_outline_rounded,
                                    label: 'Conversar',
                                  ),
                                  const SizedBox(width: 8),
                                  _ChatHintChip(
                                    icon: Icons.receipt_long_rounded,
                                    label: 'Comprobantes',
                                  ),
                                ],
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
                                (storedPhotoUrl == null ||
                                        storedPhotoUrl.isEmpty
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
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
              decoration: BoxDecoration(
                color: Colors.white,
                border: const Border(top: BorderSide(color: Color(0xFFDCE8EF))),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF173B75).withValues(alpha: 0.09),
                    blurRadius: 18,
                    offset: const Offset(0, -6),
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
                          padding: const EdgeInsets.only(top: 5, bottom: 3),
                          child: Text(
                            _isPickingImage
                                ? 'Seleccionando imagen...'
                                : _isSendingImage
                                ? _imageSendStatus
                                : 'Enviando mensaje...',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: const Color(0xFF687C8D),
                            ),
                          ),
                        ),
                      ],
                    ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0F6FA),
                            borderRadius: BorderRadius.circular(27),
                            border: Border.all(color: const Color(0xFFDCE8EF)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const SizedBox(width: 15),
                              Expanded(
                                child: TextField(
                                  controller: _messageController,
                                  textCapitalization:
                                      TextCapitalization.sentences,
                                  minLines: 1,
                                  maxLines: 5,
                                  decoration: const InputDecoration(
                                    hintText: 'Escribe al grupo...',
                                    hintStyle: TextStyle(
                                      color: Color(0xFF8293A0),
                                    ),
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.symmetric(
                                      vertical: 13,
                                    ),
                                  ),
                                  onSubmitted: (_) => _sendMessage(),
                                ),
                              ),
                              IconButton(
                                onPressed: _isSending
                                    ? null
                                    : _pickAndSendImage,
                                tooltip: 'Adjuntar imagen o comprobante',
                                style: IconButton.styleFrom(
                                  foregroundColor: const Color(0xFF087F8C),
                                  disabledForegroundColor: const Color(
                                    0xFFAAC3CE,
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.add_photo_alternate_rounded,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 3),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 9),
                      SizedBox(
                        width: 50,
                        height: 50,
                        child: IconButton.filled(
                          onPressed: _isSending ? null : _sendMessage,
                          tooltip: 'Enviar mensaje',
                          style: IconButton.styleFrom(
                            backgroundColor: const Color(0xFF2457C5),
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: const Color(0xFFB7C8D5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          icon: const Icon(Icons.send_rounded, size: 21),
                        ),
                      ),
                    ],
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

class _ChatHintChip extends StatelessWidget {
  const _ChatHintChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F6FA),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDCE8EF)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF087F8C)),
          const SizedBox(width: 5),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: const Color(0xFF496578),
              fontWeight: FontWeight.w700,
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
    final imageBase64 = message.imageBase64?.trim();
    Uint8List? imageBytes;
    if (imageBase64 != null && imageBase64.isNotEmpty) {
      try {
        imageBytes = base64Decode(imageBase64);
      } on FormatException catch (error) {
        debugPrint(
          'El comprobante del mensaje ${message.id} no es Base64 válido: $error',
        );
      }
    }
    final ImageProvider<Object>? imageProvider = imageBytes != null
        ? MemoryImage(imageBytes)
        : imageUrl != null && imageUrl.isNotEmpty
        ? NetworkImage(imageUrl)
        : null;
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
          if (imageProvider != null) ...[
            const SizedBox(height: 6),
            GestureDetector(
              onTap: () => _previewImage(context, imageProvider),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image(
                  image: imageProvider,
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
            if (imageProvider != null) const SizedBox(height: 6),
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

  void _previewImage(
    BuildContext context,
    ImageProvider<Object> imageProvider,
  ) {
    showDialog<void>(
      context: context,
      builder: (context) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          title: const Text('Comprobante de pago'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: SafeArea(
          child: Center(
            child: InteractiveViewer(
              minScale: 0.8,
              maxScale: 5,
              child: Image(
                image: imageProvider,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => const Icon(
                  Icons.broken_image_outlined,
                  color: Colors.white,
                  size: 48,
                ),
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
