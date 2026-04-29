import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../Providers/chatProvider.dart';
import '../Screens/AuthWrapper.dart';
import '../services/creditService.dart';

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
  User? _currentUser;
  bool _isCheckingAuth = true;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();

    _dotsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();

    _checkAuthStatus();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom(animated: false);
    });
  }

  // Check authentication status from Firebase Auth
  void _checkAuthStatus() {
    _currentUser = FirebaseAuth.instance.currentUser;
    setState(() {
      _isCheckingAuth = false;
    });
  }

  // Listen to auth state changes
  void _setupAuthListener() {
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (mounted) {
        setState(() {
          _currentUser = user;
          _isCheckingAuth = false;
        });
      }
    });
  }

  // Navigate to AuthWrapper
  void _navigateToAuth() {
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (context) => AuthWrapper(isHome: true),
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _setupAuthListener();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _dotsController.dispose();
    super.dispose();
  }

  void _sendMessage(ChatProvider provider) async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    await CreditsService.confirmUsageAndCheckBalance(
      context: context,
      actionName: "AI Study Buddy Reply",
      onConfirmedAction: () async {
        provider.sendMessage(text);
        _controller.clear();
        Future.delayed(const Duration(milliseconds: 250), () => _scrollToBottom());
      },
    );
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
              onCharTyped: _scrollToBottom,
              onComplete: _scrollToBottom,
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

  /// Optional pre-set question suggestions
  Widget _buildSuggestedQuestions(ChatProvider chatProvider) {
    if (chatProvider.messages.isNotEmpty) return const SizedBox.shrink();

    final suggestions = [
      "Summarize my topic",
      "Explain a complex concept",
      "Create a quick quiz",
      "Give me study tips"
    ];

    return Container(
      height: 40,
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        scrollDirection: Axis.horizontal,
        itemCount: suggestions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          return ActionChip(
            label: Text(suggestions[index], style: const TextStyle(fontSize: 13, color: Color(0xFF5E35B1), fontWeight: FontWeight.w600)),
            backgroundColor: Colors.deepPurple.shade50,
            side: BorderSide.none,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            padding: const EdgeInsets.symmetric(horizontal: 4),
            onPressed: () {
              _controller.text = suggestions[index];
              _sendMessage(chatProvider);
            },
          );
        },
      ),
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

  /// Login/Signup Prompt Screen
  Widget _buildLoginPrompt() {
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
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.chat_bubble_outline,
                        size: 80,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        "Join the Conversation",
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                          decoration: TextDecoration.none
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        "Login to start chatting with your AI Study Buddy and get personalized help with your studies",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.black54,
                            decoration: TextDecoration.none
                        ),
                      ),
                      const SizedBox(height: 30),
                      SizedBox(
                        width: double.infinity,
                        child: CupertinoButton(
                          onPressed: _navigateToAuth,
                          color: const Color(0xFF5E35B1),
                          child: const Text(
                            "Login to Continue",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 15),
                      SizedBox(
                        width: double.infinity,
                        child: CupertinoButton(
                          onPressed: _navigateToAuth,
                          color: Colors.grey[200],
                          child: const Text(
                            "Create Account",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF5E35B1),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Loading screen while checking auth status
  Widget _buildLoadingScreen() {
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
      child: const SafeArea(
        child: Center(
          child: CupertinoActivityIndicator(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Show loading screen while checking auth status
    if (_isCheckingAuth) {
      return _buildLoadingScreen();
    }

    // Show login prompt if not logged in
    if (_currentUser == null) {
      return _buildLoginPrompt();
    }

    // Show original chat screen for logged in users
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
                      final bool isTyping = !msg.isUser && index == messages.length - 1 && chatProvider.isLoading == true;
                      return _buildMessageBubble(msg.text, msg.isUser, isTyping: isTyping);
                    },
                  ),
                ),
                _buildSuggestedQuestions(chatProvider),
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
  final VoidCallback? onCharTyped;

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
        widget.onCharTyped?.call();
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

