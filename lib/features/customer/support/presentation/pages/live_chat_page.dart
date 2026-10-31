import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:app/core/widgets/bounce_button.dart';
import 'package:app/features/customer/support/presentation/widgets/chat_bubble.dart';
import 'package:app/features/customer/support/domain/services/mistral_chat_service.dart';
import 'package:intl/intl.dart';

class LiveChatPage extends StatefulWidget {
  const LiveChatPage({super.key});

  @override
  State<LiveChatPage> createState() => _LiveChatPageState();
}

class _LiveChatPageState extends State<LiveChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final MistralChatService _chatService = MistralChatService();

  final List<ChatMessageData> _messages = [];
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    // Add initial welcome message
    _messages.addAll([
      ChatMessageData(
        text: "Hi there!\nHow can we help you today?",
        sender: MessageSender.ai,
        time: _formatTime(DateTime.now()),
      ),
    ]);
  }

  String _formatTime(DateTime time) {
    return DateFormat('h:mm a').format(time);
  }

  Widget _buildActionChip(IconData icon, String label) {
    return BounceButton(
      onTap: () => _sendMessage(label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: const Color(0xFF1B3D2F)),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1B3D2F),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    final userMessage = ChatMessageData(
      text: text,
      sender: MessageSender.user,
      time: _formatTime(DateTime.now()),
    );

    setState(() {
      _messages.add(userMessage);
      _isTyping = true;
      _messageController.clear();
    });

    _scrollToBottom();

    try {
      // Map UI messages to API format
      final history = _messages
          .where((m) => !m.isRichUi)
          .map(
            (m) => ChatMessage(
              role: m.sender == MessageSender.user ? 'user' : 'assistant',
              content: m.text,
            ),
          )
          .toList();

      final responseText = await _chatService.sendMessage(history, text);

      setState(() {
        _isTyping = false;
        _messages.add(
          ChatMessageData(
            text: responseText,
            sender: MessageSender.ai,
            time: _formatTime(DateTime.now()),
          ),
        );
      });
      _scrollToBottom();
    } catch (e) {
      setState(() {
        _isTyping = false;
        _messages.add(
          ChatMessageData(
            text: "Sorry, I encountered an error. Please try again.",
            sender: MessageSender.ai,
            time: _formatTime(DateTime.now()),
          ),
        );
      });
      _scrollToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
        ),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        leading: BounceButton(
          onTap: () => Navigator.pop(context),
          child: const Icon(
            Icons.arrow_back,
            color: Color(0xFF1E2022),
            size: 24,
          ),
        ),
        title: const Text(
          'Talk with Us',
          style: TextStyle(
            color: Color(0xFF1E2022),
            fontWeight: FontWeight.w900,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert, color: Color(0xFF1E2022)),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          // Welcome Banner
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF4FBF4),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    color: Color(0xFFEAF5EF),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.support_agent,
                    color: Color(0xFF3BA772),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Customer Support',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Color(0xFF1E2022),
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        "We're here to help with your orders and questions",
                        style: TextStyle(
                          color: Color(0xFF5A6B62),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Chat Messages
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _messages.length + (_isTyping ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length) {
                  return Padding(
                    padding: const EdgeInsets.only(left: 48, top: 8, bottom: 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'AI is typing...',
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  );
                }
                return ChatBubble(message: _messages[index]);
              },
            ),
          ),

          // Bottom Suggestions (if needed)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _buildActionChip(
                  Icons.location_on_outlined,
                  'Change Delivery Address',
                ),
                const SizedBox(width: 8),
                _buildActionChip(Icons.cancel_outlined, 'Cancel Order'),
                const SizedBox(width: 8),
                _buildActionChip(Icons.person_outline, 'Contact Agent'),
              ],
            ),
          ),

          // Input Area
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey.shade100)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.attach_file_outlined,
                  color: Colors.grey.shade500,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        hintStyle: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 13,
                        ),
                        border: InputBorder.none,
                      ),
                      onSubmitted: _sendMessage,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                BounceButton(
                  onTap: () => _sendMessage(_messageController.text),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(
                      color: Color(0xFF1B3D2F),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.send_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Footer
          Padding(
            padding: const EdgeInsets.only(bottom: 16, top: 4),
            child: Text(
              'Powered by GroceryApp Support',
              style: TextStyle(color: Colors.grey.shade400, fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }
}
