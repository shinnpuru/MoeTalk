import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'utils.dart' show Message;
import 'comic_overlay.dart';

// 全局显示设置（由 main.dart 或 storage 初始化时填充）
class DisplaySettings {
  double fontSize;
  String textColorHex;
  String nameColorHex;
  bool textOutline;
  double outlineWidth;
  String outlineColorHex;

  DisplaySettings({
    this.fontSize = 20.0,
    this.textColorHex = '',
    this.nameColorHex = '',
    this.textOutline = true,
    this.outlineWidth = 2.0,
    this.outlineColorHex = '',
  });
}

DisplaySettings displaySettings = DisplaySettings();

/// 应用描边到 TextStyle
TextStyle _applyOutline(TextStyle style, {double? strokeWidth, Color? strokeColor}) {
  if (!displaySettings.textOutline) return style;
  final width = strokeWidth ?? displaySettings.outlineWidth;
  Color color;
  if (displaySettings.outlineColorHex.isNotEmpty) {
    try {
      final hex = displaySettings.outlineColorHex.replaceFirst('#', '');
      color = Color(int.parse('FF${hex.padLeft(6, '0').substring(0, 6)}', radix: 16));
    } catch (_) {
      color = strokeColor ?? Colors.black26;
    }
  } else {
    color = strokeColor ?? Colors.black26;
  }
  return style.copyWith(
    shadows: [
      Shadow(offset: Offset(-width, -width), color: color),
      Shadow(offset: Offset(width, -width), color: color),
      Shadow(offset: Offset(-width, width), color: color),
      Shadow(offset: Offset(width, width), color: color),
    ],
  );
}

/// 根据 hex 颜色字符串或主题返回颜色
Color _resolveTextColor(Color defaultColor, {String? hexOverride}) {
  final hex = hexOverride ?? displaySettings.textColorHex;
  if (hex.isNotEmpty) {
    try {
      final c = hex.replaceFirst('#', '');
      if (c.length == 6) {
        return Color(int.parse('FF$c', radix: 16));
      } else if (c.length == 8) {
        return Color(int.parse(c, radix: 16));
      }
    } catch (_) {}
  }
  return defaultColor;
}


class ChatElement extends StatelessWidget {
  final String message;
  final int type;
  final String userName;
  final String stuName;
  final bool isBacklog; // true = backlog列表模式(左对齐), false = 单条模式(居中)
  const ChatElement({super.key, required this.message, required this.type, required this.userName, required this.stuName, this.isBacklog = false});

  @override
  Widget build(BuildContext context) {
    if (type == Message.assistant) {
      return Column(crossAxisAlignment: isBacklog ? CrossAxisAlignment.start : CrossAxisAlignment.center, 
      children: [
          ChatLineLayout(name: stuName, messages: [message.replaceAll('{{user}}', userName).replaceAll('{{char}}', stuName)], isBacklog: isBacklog),
          const SizedBox(height: 10),
        ]);
    } else if (type == Message.user) {
      return Column(
        crossAxisAlignment: isBacklog ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          ChatLineLayout(name: userName, messages: [message.replaceAll('{{user}}', userName).replaceAll('{{char}}', stuName)], isBacklog: isBacklog),
          const SizedBox(height: 10),
        ],
      );
    } else if (type == Message.timestamp){
      DateTime t = DateTime.fromMillisecondsSinceEpoch(int.parse(message));
      String timestr = "${t.hour.toString().padLeft(2,'0')}:"
        "${t.minute.toString().padLeft(2,'0')}";
      return centerBubble(timestr);
    } else if (type == Message.system) {
      return centerBubble(message.replaceAll('{{user}}', userName).replaceAll('{{char}}', stuName));
    } else if (type == Message.image) {
      return ChatLineImage(name: stuName, imageUrl: message, isBacklog: isBacklog);
    }
    else {
      return const SizedBox.shrink();
    }
  }
}

Widget centerBubble(String msg) {
  final fontSize = displaySettings.fontSize - 2;
  TextStyle style = TextStyle(fontSize: fontSize, color: Colors.black54);
  style = _applyOutline(style, strokeColor: Colors.black12);

  return Column(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Container(
        decoration: BoxDecoration(
          color: const Color(0xCCdce5ec),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
        child: MarkdownBody(
          data: msg,
          shrinkWrap: true,
          styleSheet: MarkdownStyleSheet(
            p: style,
          ),
        ),
      ),
      const SizedBox(height: 5),
    ],
  );
}

/// 新的聊天行布局：名字（居中）→ 分割线 → 内容（居中）
class ChatLineLayout extends StatelessWidget {
  final String name;
  final List<String> messages;
  final bool isBacklog;

  const ChatLineLayout({
    super.key,
    required this.name,
    required this.messages,
    this.isBacklog = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? Colors.white : Colors.black87;
    final textColor = _resolveTextColor(baseColor);
    final dividerColor = isDark ? Colors.white38 : Colors.black26;
    final nameDefault = isDark ? Colors.white70 : Colors.black54;
    final nameColor = _resolveTextColor(nameDefault, hexOverride: displaySettings.nameColorHex);
    final fontSize = displaySettings.fontSize;
    final outlineWidth = displaySettings.outlineWidth;

    final crossAlign = isBacklog ? CrossAxisAlignment.start : CrossAxisAlignment.center;
    final textAlign = isBacklog ? TextAlign.left : TextAlign.center;
    final contentAlign = isBacklog ? Alignment.centerLeft : Alignment.center;

    // 带描边的基础 TextStyle
    TextStyle baseTextStyle = TextStyle(
      fontSize: fontSize,
      color: textColor,
    );
    baseTextStyle = _applyOutline(baseTextStyle, strokeWidth: outlineWidth);

    TextStyle boldTextStyle = baseTextStyle.copyWith(fontWeight: FontWeight.bold);
    TextStyle italicTextStyle = baseTextStyle.copyWith(fontStyle: FontStyle.italic);

    return Column(
      crossAxisAlignment: crossAlign,
      children: [
        // 名字（backlog左对齐，单条模式居中）
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Text(
            name,
            textAlign: textAlign,
            style: _applyOutline(TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: nameColor,
            ), strokeWidth: outlineWidth),
          ),
        ),
        // 分割线
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Divider(
            color: dividerColor,
            height: 1,
            thickness: 1,
          ),
        ),
        const SizedBox(height: 8),
        // 内容（backlog左对齐，单条模式居中）
        ...messages.asMap().entries.map((entry) {
          String message = entry.value;
          if (message.isEmpty) {
            return const SizedBox.shrink();
          }
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: contentAlign,
              child: Container(
                constraints: const BoxConstraints(minHeight: 44, maxWidth: 600),
                child: MarkdownBody(
                  data: message,
                  shrinkWrap: true,
                  styleSheet: MarkdownStyleSheet(
                    p: baseTextStyle,
                    strong: boldTextStyle,
                    em: italicTextStyle,
                    a: TextStyle(fontSize: fontSize, color: Colors.blue, decoration: TextDecoration.underline),
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}

class ChatLineImage extends StatelessWidget {
  final String name;
  final String imageUrl;
  final bool isBacklog;

  const ChatLineImage({
    super.key,
    required this.name,
    required this.imageUrl,
    this.isBacklog = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dividerColor = isDark ? Colors.white38 : Colors.black26;
    final nameDefault = isDark ? Colors.white70 : Colors.black54;
    final nameColor = _resolveTextColor(nameDefault, hexOverride: displaySettings.nameColorHex);
    final outlineWidth = displaySettings.outlineWidth;

    final crossAlign = isBacklog ? CrossAxisAlignment.start : CrossAxisAlignment.center;
    final textAlign = isBacklog ? TextAlign.left : TextAlign.center;
    final contentAlign = isBacklog ? Alignment.centerLeft : Alignment.center;

    return Column(
      crossAxisAlignment: crossAlign,
      children: [
        // 名字（backlog左对齐，单条模式居中）
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Text(
            name,
            textAlign: textAlign,
            style: _applyOutline(TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: nameColor,
            ), strokeWidth: outlineWidth),
          ),
        ),
        // 分割线
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Divider(
            color: dividerColor,
            height: 1,
            thickness: 1,
          ),
        ),
        const SizedBox(height: 8),
        // 图片内容（backlog左对齐，单条模式居中）
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Align(
            alignment: contentAlign,
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
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 漫画模式聊天视图 — 全屏 CG + 浮动气泡
class ComicChatView extends StatefulWidget {
  final List<MapEntry<int, Message>> messages;
  final String userName;
  final String stuName;
  final bool isBacklog;
  final VoidCallback? onNextPage;

  const ComicChatView({
    super.key,
    required this.messages,
    required this.userName,
    required this.stuName,
    this.isBacklog = false,
    this.onNextPage,
  });

  @override
  ComicChatViewState createState() => ComicChatViewState();
}

class ComicChatViewState extends State<ComicChatView> {
  int _currentIndex = 0;
  final GlobalKey<ComicBubbleOverlayState> _overlayKey = GlobalKey();

  List<_ComicPage> _buildPages() {
    List<_ComicPage> pages = [];
    List<Message> textBuffer = [];

    for (var entry in widget.messages) {
      final msg = entry.value;
      if (msg.type == Message.image) {
        if (textBuffer.isNotEmpty) {
          pages.add(_ComicPage(
            cgUrl: null,
            textMessages: List.from(textBuffer),
          ));
          textBuffer.clear();
        }
        pages.add(_ComicPage(
          cgUrl: msg.message,
          textMessages: [],
        ));
      } else if (msg.type == Message.assistant || msg.type == Message.user) {
        if (pages.isNotEmpty && pages.last.cgUrl != null) {
          pages.last.textMessages.add(msg);
        } else {
          textBuffer.add(msg);
        }
      }
    }

    if (textBuffer.isNotEmpty) {
      if (pages.isEmpty) {
        pages.add(_ComicPage(
          cgUrl: null,
          textMessages: List.from(textBuffer),
        ));
      } else {
        pages.last.textMessages.addAll(textBuffer);
      }
    }

    if (pages.isEmpty) {
      pages.add(_ComicPage(cgUrl: null, textMessages: []));
    }

    return pages;
  }

  void _nextPage() {
    final pages = _buildPages();
    if (_currentIndex < pages.length - 1) {
      setState(() {
        _currentIndex++;
      });
    }
    widget.onNextPage?.call();
  }

  void _prevPage() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = _buildPages();
    if (pages.isEmpty) {
      return const Center(child: Text('暂无消息'));
    }

    if (_currentIndex >= pages.length) {
      _currentIndex = pages.length - 1;
    }

    final page = pages[_currentIndex];

    String bubbleText = '';
    String bubbleSpeaker = widget.stuName;
    if (page.textMessages.isNotEmpty) {
      final lastMsg = page.textMessages.last;
      bubbleText = lastMsg.message;
      bubbleSpeaker = lastMsg.type == Message.user ? widget.userName : widget.stuName;
    }

    return GestureDetector(
      onTap: _nextPage,
      onHorizontalDragEnd: (details) {
        if (details.primaryVelocity != null) {
          if (details.primaryVelocity! < 0) {
            _nextPage();
          } else {
            _prevPage();
          }
        }
      },
      child: Stack(
        children: [
          ComicBubbleOverlay(
            key: _overlayKey,
            text: bubbleText,
            speaker: bubbleSpeaker,
            cgUrl: page.cgUrl,
          ),
          if (pages.length > 1)
            Positioned(
              bottom: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_currentIndex + 1} / ${pages.length}',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ),
          if (_currentIndex < pages.length - 1)
            Positioned(
              right: 8,
              top: 0,
              bottom: 40,
              child: Center(
                child: Icon(
                  Icons.chevron_right,
                  color: Colors.white.withValues(alpha: 0.3),
                  size: 36,
                ),
              ),
            ),
          if (_currentIndex > 0)
            Positioned(
              left: 8,
              top: 0,
              bottom: 40,
              child: Center(
                child: Icon(
                  Icons.chevron_left,
                  color: Colors.white.withValues(alpha: 0.3),
                  size: 36,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ComicPage {
  final String? cgUrl;
  final List<Message> textMessages;

  _ComicPage({
    required this.cgUrl,
    required this.textMessages,
  });
}
