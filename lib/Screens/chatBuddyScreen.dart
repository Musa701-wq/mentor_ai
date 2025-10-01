import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../Providers/chatProvider.dart';

class ChatBuddyScreen extends StatefulWidget {
  const ChatBuddyScreen({super.key});

  @override
  State<ChatBuddyScreen> createState() => _ChatBuddyScreenState();
}

class _ChatBuddyScreenState extends State<ChatBuddyScreen>
    with TickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late final FocusNode _focusNode;
  late final AnimationController _dotsController;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();

    _dotsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom(animated: false);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _dotsController.dispose();
    super.dispose();
  }

  void _sendMessage(ChatProvider provider) {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    provider.sendMessage(text);
    _controller.clear();
    Future.delayed(const Duration(milliseconds: 250), () => _scrollToBottom());
  }

  void _scrollToBottom({bool animated = true}) {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position.maxScrollExtent;
    if (animated) {
      _scrollController.animateTo(
        pos,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } else {
      _scrollController.jumpTo(pos);
    }
  }

  /// Chat bubble (AI or User)
  Widget _buildMessageBubble(String text, bool isUser, {bool isTyping = false}) {
    final maxBubbleWidth = MediaQuery.of(context).size.width * 0.7;

    return Row(
      mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (!isUser)
          const CircleAvatar(
            radius: 16,
            backgroundColor: Color(0xFF5E35B1),
            child: Icon(Icons.smart_toy, color: Colors.white, size: 16),
          ),
        if (!isUser) const SizedBox(width: 6),
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxBubbleWidth),
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isUser ? const Color(0xFF5E35B1) : Colors.grey.shade200,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(14),
                topRight: const Radius.circular(14),
                bottomLeft: Radius.circular(isUser ? 14 : 4),
                bottomRight: Radius.circular(isUser ? 4 : 14),
              ),
            ),
            child: isUser || !isTyping
                ? Text(
              text,
              style: TextStyle(
                color: isUser ? Colors.white : Colors.black87,
                fontSize: 15,
                decoration: TextDecoration.none,
                fontWeight: FontWeight.normal
              ),
            )
                : TypingText(
              text: text,
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 15,
                decoration: TextDecoration.none,
                fontWeight: FontWeight.normal
              ),
              speed: const Duration(milliseconds: 30),
              onCharTyped: _scrollToBottom, // scroll after each character
              onComplete: _scrollToBottom, // refresh to mark complete
            ),
          ),
        ),
        if (isUser) const SizedBox(width: 6),
        if (isUser)
          const CircleAvatar(
            radius: 16,
            backgroundColor: Colors.blueAccent,
            child: Icon(Icons.person, color: Colors.white, size: 16),
          ),
      ],
    );
  }


  /// Animated typing dots
  Widget _buildTypingDots() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const CircleAvatar(
          radius: 16,
          backgroundColor: Color(0xFF5E35B1),
          child: Icon(Icons.smart_toy, color: Colors.white, size: 16),
        ),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(14),
              topRight: Radius.circular(14),
              bottomRight: Radius.circular(14),
              bottomLeft: Radius.circular(4),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (i) {
              return AnimatedBuilder(
                animation: _dotsController,
                builder: (context, child) {
                  double t = (_dotsController.value + (i * 0.2)) % 1.0;
                  double offset = (t < 0.5 ? t : 1 - t) * 6;
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    child: Transform.translate(
                      offset: Offset(0, -offset),
                      child: child,
                    ),
                  );
                },
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Colors.grey,
                    shape: BoxShape.circle,
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  /// Input bar
  Widget _buildInputBar(ChatProvider chatProvider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: CupertinoTextField(
              controller: _controller,
              focusNode: _focusNode,
              placeholder: "Ask about your studies...",
              padding:
              const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(18),
              ),
              onSubmitted: (_) => _sendMessage(chatProvider),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _sendMessage(chatProvider),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(
                color: Color(0xFF5E35B1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.send, color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ChatProvider>(
      builder: (context, chatProvider, _) {
        final messages = chatProvider.messages;

        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToBottom(animated: true);
        });

        return CupertinoPageScaffold(
          navigationBar: CupertinoNavigationBar(
            leading: CupertinoNavigationBarBackButton(
              onPressed: () => Navigator.pop(context),
            ),
            middle: const Text(
              "Study Buddy",
              style: TextStyle(fontSize: 18),
            ),
            backgroundColor: Colors.white,
          ),
          child: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: messages.isEmpty
                      ? const Center(
                    child: Text(
                      "No messages yet.\nAsk me anything about your studies!",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.black54,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  )
                      : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(12),
                    itemCount: messages.length +
                        (chatProvider.isLoading ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (chatProvider.isLoading &&
                          index == messages.length) {
                        return _buildTypingDots();
                      }
                      final msg = messages[index];
                      final bool isTyping = !msg.isUser && index == messages.length - 1 && chatProvider.isLoading == false;
                      return _buildMessageBubble(msg.text, msg.isUser, isTyping: isTyping);
                    },
                  ),
                ),
                _buildInputBar(chatProvider),
              ],
            ),
          ),
        );
      },
    );
  }

}


class TypingText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final Duration speed;
  final VoidCallback? onComplete;
  final VoidCallback? onCharTyped; // called after each char

  const TypingText({
    super.key,
    required this.text,
    this.style,
    this.speed = const Duration(milliseconds: 30),
    this.onComplete,
    this.onCharTyped,
  });

  @override
  _TypingTextState createState() => _TypingTextState();
}

class _TypingTextState extends State<TypingText> {
  String _displayedText = '';
  int _currentIndex = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTyping();
  }

  void _startTyping() {
    _timer = Timer.periodic(widget.speed, (timer) {
      if (_currentIndex < widget.text.length) {
        setState(() {
          _displayedText += widget.text[_currentIndex];
          _currentIndex++;
        });
        widget.onCharTyped?.call(); // scroll after each char
      } else {
        _timer?.cancel();
        widget.onComplete?.call();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _displayedText,
      style: widget.style,
    );
  }
}

