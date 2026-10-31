import 'package:flutter/material.dart';

enum MessageSender { user, ai }

class ChatMessageData {
  final String text;
  final MessageSender sender;
  final String time;
  final bool isRichUi;
  final Widget? richWidget;

  ChatMessageData({
    required this.text,
    required this.sender,
    required this.time,
    this.isRichUi = false,
    this.richWidget,
  });
}

class ChatBubble extends StatelessWidget {
  final ChatMessageData message;

  const ChatBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.sender == MessageSender.user;

    if (message.isRichUi && message.richWidget != null && !isUser) {
      return Padding(
        padding: const EdgeInsets.only(left: 48, top: 8, bottom: 8, right: 16),
        child: Align(
          alignment: Alignment.centerLeft,
          child: message.richWidget!,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: Row(
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            Container(
              width: 24,
              height: 24,
              decoration: const BoxDecoration(
                color: Color(0xFF1B3D2F),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.support_agent,
                color: Colors.white,
                size: 14,
              ),
            ),
            const SizedBox(width: 8),
          ],

          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isUser ? const Color(0xFF1B3D2F) : Colors.grey.shade100,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: isUser ? const Radius.circular(16) : Radius.zero,
                  bottomRight: isUser ? Radius.zero : const Radius.circular(16),
                ),
              ),
              child: Column(
                crossAxisAlignment: isUser
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    message.text,
                    style: TextStyle(
                      color: isUser ? Colors.white : const Color(0xFF1E2022),
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        message.time,
                        style: TextStyle(
                          color: isUser
                              ? Colors.white.withValues(alpha: 0.7)
                              : Colors.grey.shade500,
                          fontSize: 9,
                        ),
                      ),
                      if (isUser) ...[
                        const SizedBox(width: 4),
                        Icon(
                          Icons.done_all,
                          color: Colors.white.withValues(alpha: 0.8),
                          size: 12,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),

          if (isUser) const SizedBox(width: 32),
        ],
      ),
    );
  }
}
