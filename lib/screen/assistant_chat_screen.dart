import 'package:flutter/material.dart';
import '../services/assistant_service.dart';

class AssistantChatScreen extends StatefulWidget {
  const AssistantChatScreen({super.key});

  @override
  State<AssistantChatScreen> createState() => _AssistantChatScreenState();
}

class _AssistantChatScreenState extends State<AssistantChatScreen> {
  static const _welcomeMessage =
      '¡Hola! Soy el asistente de SplitEasy. Puedo ayudarte a organizar '
      'gastos compartidos, entender cómo dividir una cuenta o resolver dudas '
      'sobre la app. ¿Qué necesitas?';
  static const _maxMessageLength = 2000;

  final _service = AssistantService();
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final _messages = <_ChatMessage>[
    const _ChatMessage(text: _welcomeMessage, isUser: false),
  ];
  final _history = <Map<String, String>>[];
  bool _isSending = false;

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (_isSending || text.isEmpty) return;
    if (text.length > _maxMessageLength) {
      _showMessage('El mensaje no puede superar los 2.000 caracteres.');
      return;
    }

    _textController.clear();
    final requestHistory = [
      ..._history,
      {'role': 'user', 'text': text},
    ];
    if (requestHistory.length > 12) {
      requestHistory.removeRange(0, 2);
    }

    setState(() {
      _messages.add(_ChatMessage(text: text, isUser: true));
      _isSending = true;
    });
    _scrollToLatest();

    try {
      final reply = await _service.sendMessage(requestHistory);
      if (!mounted) return;
      _history
        ..clear()
        ..addAll(requestHistory)
        ..add({'role': 'model', 'text': reply});
      if (_history.length > 12) {
        _history.removeRange(0, 2);
      }
      setState(() => _messages.add(_ChatMessage(text: reply, isUser: false)));
    } on AssistantServiceException catch (error) {
      if (!mounted) return;
      setState(
        () => _messages.add(
          _ChatMessage(text: _getAssistantErrorMessage(error), isUser: false),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _messages.add(
          const _ChatMessage(
            text: 'No pude conectar con el asistente. Revisa tu conexión e '
                'inténtalo nuevamente.',
            isUser: false,
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
        _scrollToLatest();
      }
    }
  }

  String _getAssistantErrorMessage(AssistantServiceException error) {
    switch (error.code) {
      case 'unauthenticated':
        return 'Inicia sesión nuevamente para usar el asistente.';
      case 'resource-exhausted':
        return 'Alcanzaste el límite temporal de mensajes. Espera un minuto '
            'e inténtalo otra vez.';
      case 'invalid-argument':
        return 'El mensaje no es válido o es demasiado largo.';
      case 'unavailable':
        return 'El asistente no está disponible por el momento. Inténtalo '
            'más tarde.';
      case 'not-configured':
        return 'Falta configurar la URL del asistente. Revisa los pasos del '
            'README.';
      default:
        return 'No se pudo obtener una respuesta. Inténtalo nuevamente.';
    }
  }

  void _startNewConversation() {
    if (_isSending) return;
    setState(() {
      _history.clear();
      _messages
        ..clear()
        ..add(const _ChatMessage(text: _welcomeMessage, isUser: false));
    });
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _scrollToLatest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Asistente IA'),
        actions: [
          IconButton(
            tooltip: 'Nueva conversación',
            onPressed: _isSending ? null : _startNewConversation,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 20,
                    ),
                    itemCount: _messages.length + (_isSending ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (_isSending && index == _messages.length) {
                        return const _TypingIndicator();
                      }
                      return _MessageBubble(message: _messages[index]);
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text(
                    'La conversación no se guarda. El asistente no ve tus '
                    'grupos ni gastos.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _textController,
                          minLines: 1,
                          maxLines: 5,
                          maxLength: _maxMessageLength,
                          textCapitalization: TextCapitalization.sentences,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _sendMessage(),
                          decoration: InputDecoration(
                            hintText: 'Escribe tu mensaje...',
                            counterText: '',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        tooltip: 'Enviar mensaje',
                        onPressed: _isSending ? null : _sendMessage,
                        icon: const Icon(Icons.send_rounded),
                      ),
                    ],
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

class _ChatMessage {
  const _ChatMessage({required this.text, required this.isUser});

  final String text;
  final bool isUser;
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final _ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final alignment = message.isUser
        ? CrossAxisAlignment.end
        : CrossAxisAlignment.start;
    final background = message.isUser
        ? colors.primaryContainer
        : colors.surfaceContainerHighest;
    final foreground = message.isUser
        ? colors.onPrimaryContainer
        : colors.onSurface;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: alignment,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width * 0.78,
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: SelectableText(
                  message.text,
                  style: TextStyle(color: foreground, height: 1.4),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      ),
    );
  }
}
