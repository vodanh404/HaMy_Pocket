import 'dart:async';

import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../services/ai/qwen_chat_service.dart';
import '../../services/speech/speech_service.dart';
import 'conversation_topics.dart';

class ConversationChatScreen extends StatefulWidget {
  const ConversationChatScreen({required this.topic, super.key});

  final ConversationTopic topic;

  @override
  State<ConversationChatScreen> createState() => _ConversationChatScreenState();
}

class _ConversationChatScreenState extends State<ConversationChatScreen> {
  final QwenChatService _qwen = QwenChatService.instance;
  final SpeechToText _speech = SpeechToText();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<_ConversationMessage> _messages = [];

  bool _isListening = false;
  bool _isGenerating = false;
  bool _speechInitialized = false;
  bool _isSpeaking = false;
  String? _speechLocale;
  StreamSubscription<String>? _replySubscription;

  @override
  void initState() {
    super.initState();
    _qwen.startConversation(
      systemPrompt: widget.topic.systemPrompt,
      openingMessage: widget.topic.openingMessage,
    );
    _messages.add(
      _ConversationMessage(text: widget.topic.openingMessage, isUser: false),
    );
  }

  Future<void> _toggleListening() async {
    if (_isListening) {
      await _speech.stop();
      if (mounted) setState(() => _isListening = false);
      return;
    }

    try {
      if (!_speechInitialized) {
        final available = await _speech.initialize(
          onError: (error) {
            if (mounted) {
              setState(() => _isListening = false);
              _showMessage('Nhận dạng giọng nói gặp lỗi: ${error.errorMsg}');
            }
          },
          onStatus: (status) {
            if (mounted && status == 'notListening' && _isListening) {
              setState(() => _isListening = false);
            }
          },
        );
        if (!available) {
          _showMessage(
            'Thiết bị chưa bật được nhận dạng giọng nói. Kiểm tra dịch vụ '
            'nhận dạng và ngôn ngữ tiếng Trung.',
          );
          return;
        }
        _speechInitialized = true;
        final locales = await _speech.locales();
        _speechLocale = locales
            .where((locale) => locale.localeId.toLowerCase().startsWith('zh'))
            .map((locale) => locale.localeId)
            .firstOrNull;
      }

      if (_speechLocale == null) {
        _showMessage('Thiết bị chưa cài ngôn ngữ nhận dạng tiếng Trung.');
        return;
      }

      await _speech.listen(
        onResult: _onSpeechResult,
        localeId: _speechLocale,
        listenFor: const Duration(seconds: 15),
        pauseFor: const Duration(seconds: 3),
        listenOptions: SpeechListenOptions(
          partialResults: true,
          listenMode: ListenMode.dictation,
        ),
      );
      if (mounted) setState(() => _isListening = _speech.isListening);
    } on Object catch (error) {
      _showMessage('Không thể bắt đầu nhận dạng giọng nói: $error');
    }
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    final text = result.recognizedWords;
    _messageController.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    if (mounted) setState(() {});
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isGenerating) return;
    if (_isListening) unawaited(_speech.stop());

    _messageController.clear();
    setState(() {
      _isListening = false;
      _isGenerating = true;
      _messages.add(_ConversationMessage(text: text, isUser: true));
      _messages.add(_ConversationMessage(text: '', isUser: false));
    });
    _scrollToLatest();
    final responseIndex = _messages.length - 1;
    _replySubscription = _qwen.reply(text).listen(
      (chunk) {
        if (!mounted) return;
        setState(() {
          _messages[responseIndex] = _ConversationMessage(
            text: '${_messages[responseIndex].text}$chunk',
            isUser: false,
          );
        });
        _scrollToLatest();
      },
      onError: (Object error) {
        if (!mounted) return;
        setState(() {
          _isGenerating = false;
          _messages[responseIndex] = _ConversationMessage(
            text: 'Không tạo được câu trả lời: $error',
            isUser: false,
            isError: true,
          );
        });
      },
      onDone: () {
        if (!mounted) return;
        setState(() => _isGenerating = false);
        _scrollToLatest();
      },
    );
  }

  Future<void> _speakMessage(String text) async {
    final firstLine = text.split('\n').first.trim();
    final chinese = firstLine
        .replaceFirst(RegExp(r'^(中文|Chinese)\s*[:：]\s*'), '')
        .trim();
    setState(() => _isSpeaking = true);
    try {
      await speak(chinese);
    } finally {
      if (mounted) setState(() => _isSpeaking = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _scrollToLatest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    final subscription = _replySubscription;
    if (subscription != null) unawaited(subscription.cancel());
    if (_speech.isListening) unawaited(_speech.stop());
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.topic.title)),
    body: SafeArea(
      child: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                return _MessageBubble(
                  message: message,
                  onSpeak: message.isUser || message.isError || message.text.isEmpty
                      ? null
                      : () => _speakMessage(message.text),
                  isSpeaking: _isSpeaking,
                );
              },
            ),
          ),
          if (_isGenerating)
            const LinearProgressIndicator(minHeight: 2),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                IconButton(
                  tooltip: _isListening ? 'Dừng nói' : 'Nói tiếng Trung',
                  onPressed: _isGenerating ? null : _toggleListening,
                  icon: Icon(_isListening ? Icons.mic : Icons.mic_none),
                  color: _isListening
                      ? Theme.of(context).colorScheme.error
                      : null,
                ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                    decoration: InputDecoration(
                      hintText: _isListening
                          ? 'Đang nhận dạng tiếng Trung...'
                          : 'Nhập câu trả lời bằng tiếng Trung',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  tooltip: 'Gửi câu trả lời',
                  onPressed: _isGenerating ? null : _sendMessage,
                  icon: const Icon(Icons.send),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              'Nói câu trả lời bằng tiếng Trung; kiểm tra phần nhận dạng rồi nhấn gửi.',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    ),
  );
}

class _ConversationMessage {
  const _ConversationMessage({
    required this.text,
    required this.isUser,
    this.isError = false,
  });

  final String text;
  final bool isUser;
  final bool isError;
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.onSpeak,
    required this.isSpeaking,
  });

  final _ConversationMessage message;
  final VoidCallback? onSpeak;
  final bool isSpeaking;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isUser = message.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.84,
        ),
        child: Card(
          color: message.isError
              ? colors.errorContainer
              : isUser
              ? colors.primaryContainer
              : colors.surfaceContainerHigh,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText(message.text.isEmpty ? '…' : message.text),
                if (onSpeak != null)
                  Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Nghe câu tiếng Trung',
                      onPressed: isSpeaking ? null : onSpeak,
                      icon: const Icon(Icons.volume_up, size: 20),
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
