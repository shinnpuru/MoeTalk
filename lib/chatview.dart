import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'utils.dart' show Message;


class ChatElement extends StatelessWidget {
  final String message;
  final int type;
  final String userName;
  final String stuName;
  const ChatElement({super.key, required this.message, required this.type, required this.userName, required this.stuName});

  @override
  Widget build(BuildContext context) {
    if (type == Message.assistant) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for(var m in message.split("\\")) 
            if(m.isNotEmpty) 
              ChatBubbleLayoutLeft(name: stuName, messages: m.split("\\")),
          const SizedBox(height: 10),
        ]);
    } else if (type == Message.user) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          ChatBubbleLayoutRight(name: userName, messages: message.split("\\")),
          const SizedBox(height: 10),
        ],
      );
    } else if (type == Message.timestamp){
      DateTime t = DateTime.fromMillisecondsSinceEpoch(int.parse(message));
      String timestr = "${t.hour.toString().padLeft(2,'0')}:"
        "${t.minute.toString().padLeft(2,'0')}";
      return centerBubble(timestr);
    } else if (type == Message.system) {
      return centerBubble(message);
    } else if (type == Message.image) {
      return ChatBubbleImage(name: stuName, imageUrl: message);
    }
    else {
      return const SizedBox.shrink();
    }
  }
}

Widget centerBubble(String msg) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Container(
        decoration: BoxDecoration(
          color: const Color.fromARGB(204, 129, 74, 202),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
        child: MarkdownBody(
          data: msg,
          shrinkWrap: true,
          styleSheet: MarkdownStyleSheet(
            p: const TextStyle(fontSize: 18, color: Colors.white),
          ),
        )
      ),
      const SizedBox(height: 5),
    ],
  );
}

class ChatBubbleLayoutLeft extends StatelessWidget {
  final String name;
  final List<String> messages;

  const ChatBubbleLayoutLeft({
    super.key,
    required this.name,
    required this.messages
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 4),
              ...messages.asMap().entries.map((entry) {
                int idx = entry.key;
                String message = entry.value;
                if (message.isEmpty) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: CustomPaint(
                    painter:
                        BubblePainter(isFirstBubble: idx == 0, isLeft: true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      child: MarkdownBody(
                        data: message,
                        shrinkWrap: true,
                        styleSheet: MarkdownStyleSheet(
                          p: const TextStyle(fontSize: 18, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
        const SizedBox(width: 10),
      ],
    );
  }
}

class ChatBubbleImage extends StatelessWidget {
  final String name;
  final String imageUrl;

  const ChatBubbleImage({
    super.key,
    required this.name,
    required this.imageUrl
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: FractionallySizedBox(
                        widthFactor: 0.8,
                        child: Image.network(imageUrl,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) {
                              return child;
                            } else {
                              return Center(
                                child: CircularProgressIndicator(
                                  value: loadingProgress.expectedTotalBytes != null
                                      ? loadingProgress.cumulativeBytesLoaded /
                                          loadingProgress.expectedTotalBytes!
                                      : null,
                                ),
                              );
                            }
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(Icons.error);
                          },
                        )
                      )
                    )
                  ),
                ),
              )
            ],
          ),
        ),
        const SizedBox(width: 10),
      ],
    );
  }
}

// No name and avatar
class ChatBubbleLayoutRight extends StatelessWidget {
  final String name;
  final List<String> messages;

  const ChatBubbleLayoutRight({
    super.key,
    required this.name,
    required this.messages,
  });

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      const SizedBox(width: 10),
      Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
              Text(
                name,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 4),
          ...messages.asMap().entries.map((entry) {
            int idx = entry.key;
            String message = entry.value;
            if (message.isEmpty) {
              return const SizedBox.shrink();
            }
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: CustomPaint(
                painter: BubblePainter(isFirstBubble: idx == 0, isLeft: false),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: MarkdownBody(
                    data: message,
                    shrinkWrap: true,
                    styleSheet: MarkdownStyleSheet(
                      p: const TextStyle(fontSize: 18, color: Colors.white),
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
      ),
      const SizedBox(width: 10),
    ]);
  }
}

class BubblePainter extends CustomPainter {
  final bool isFirstBubble;
  final bool isLeft;

  BubblePainter({required this.isFirstBubble, required this.isLeft});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = isLeft ? const Color(0xCC4c5b70) : const Color(0xCC4a8aca)
      ..style = PaintingStyle.fill;

    final path = Path();

    if (isFirstBubble) {
      // Draw triangle for the first bubble
      if (isLeft) {
        path.moveTo(-4, 17);
        path.lineTo(4, 7);
        path.lineTo(4, 27);
        path.close();
      } else {
        path.moveTo(size.width + 4, 17);
        path.lineTo(size.width - 4, 27);
        path.lineTo(size.width - 4, 7);
        path.close();
      }
    }

    // Draw rounded rectangle for the bubble
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    path.addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(8)));

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
