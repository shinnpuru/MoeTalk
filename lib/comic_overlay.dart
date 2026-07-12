import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'chatview.dart' show displaySettings;

/// 漫画气泡叠加层 — 在全屏 CG 图上渲染一个半透明气泡
class ComicBubbleOverlay extends StatefulWidget {
  final String text;
  final String speaker; // 说话者名称
  final Uint8List? cgImage; // CG 图字节数据（可选）
  final String? cgUrl; // CG 图 URL（可选）

  const ComicBubbleOverlay({
    super.key,
    required this.text,
    required this.speaker,
    this.cgImage,
    this.cgUrl,
  });

  @override
  ComicBubbleOverlayState createState() => ComicBubbleOverlayState();
}

class ComicBubbleOverlayState extends State<ComicBubbleOverlay> {
  // 气泡位置（相对坐标 0.0~1.0）
  double _bubbleX = 0.5;
  double _bubbleY = 0.7;
  // 位置随机种子，每次翻页变化
  int _positionSeed = 0;

  @override
  void initState() {
    super.initState();
    _randomizePosition();
  }

  /// 随机生成气泡位置，确保不跑出安全区域
  void _randomizePosition() {
    final random = Random(_positionSeed);
    const double margin = 0.05; // 5% 边距
    const double faceTop = 0.25; // 面部区域上边界（假设面部在画面中央区域）
    const double faceBottom = 0.60; // 面部区域下边界

    // 候选位置区域：围绕画面四个角 + 顶部 + 底部，避开面部区域
    final List<Offset> candidates = [
      // 左上
      Offset(margin + 0.02, margin),
      // 右上
      Offset(1.0 - margin - 0.25, margin),
      // 左下
      Offset(margin + 0.02, 1.0 - margin - 0.15),
      // 右下
      Offset(1.0 - margin - 0.25, 1.0 - margin - 0.15),
      // 上中
      Offset(0.5 - 0.12, margin),
      // 下中
      Offset(0.5 - 0.12, 1.0 - margin - 0.15),
    ];

    // 再加两个稍微偏中的位置（但不遮挡面部）
    if (faceTop > 0.2) {
      candidates.add(Offset(margin + 0.02, faceTop - 0.08));
      candidates.add(Offset(1.0 - margin - 0.25, faceTop - 0.08));
    }
    if (faceBottom < 0.8) {
      candidates.add(Offset(margin + 0.02, faceBottom + 0.08));
      candidates.add(Offset(1.0 - margin - 0.25, faceBottom + 0.08));
    }

    // 随机选一个候选位置
    final pick = candidates[random.nextInt(candidates.length)];
    // 加一点微随机偏移（±2%）
    _bubbleX = (pick.dx + (random.nextDouble() - 0.5) * 0.04)
        .clamp(margin, 1.0 - margin - 0.2);
    _bubbleY = (pick.dy + (random.nextDouble() - 0.5) * 0.04)
        .clamp(margin, 1.0 - margin - 0.12);
  }

  /// 翻页时刷新位置
  void nextPage() {
    setState(() {
      _positionSeed++;
      _randomizePosition();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenW = constraints.maxWidth;
        final screenH = constraints.maxHeight;

        // 气泡大小
        final bubbleWidth = screenW * 0.55;
        final bubbleMaxHeight = screenH * 0.35;

        // 计算像素位置
        final posX = _bubbleX * screenW;
        final posY = _bubbleY * screenH;

        return Stack(
          children: [
            // CG 图背景
            Positioned.fill(
              child: _buildCGBackground(context),
            ),
            // 半透明气泡
            Positioned(
              left: posX.clamp(8.0, screenW - bubbleWidth - 8.0),
              top: posY.clamp(8.0, screenH - bubbleMaxHeight - 8.0),
              width: bubbleWidth,
              child: _buildBubble(context, isDark, bubbleMaxHeight),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCGBackground(BuildContext context) {
    if (widget.cgImage != null) {
      return Image.memory(
        widget.cgImage!,
        fit: BoxFit.contain,
        width: double.infinity,
        height: double.infinity,
      );
    }
    if (widget.cgUrl != null && widget.cgUrl!.isNotEmpty) {
      return Image.network(
        widget.cgUrl!,
        fit: BoxFit.contain,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, __, ___) => _buildFallback(context),
      );
    }
    return _buildFallback(context);
  }

  /// 无 CG 图时的占位背景
  Widget _buildFallback(BuildContext context) {
    return Container(
      color: Colors.grey[900],
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.image_outlined, size: 64, color: Colors.grey[600]),
            const SizedBox(height: 16),
            Text(
              '暂无 CG 图',
              style: TextStyle(color: Colors.grey[500], fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBubble(BuildContext context, bool isDark, double maxHeight) {
    final fontSize = displaySettings.fontSize;

    // 毛玻璃效果
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 6.0, sigmaY: 6.0),
        child: Container(
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.15)
                : Colors.black.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.25)
                  : Colors.white.withValues(alpha: 0.5),
              width: 1.5,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 说话者名字
              Text(
                widget.speaker,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white.withValues(alpha: 0.9) : Colors.white.withValues(alpha: 0.95),
                ),
              ),
              const SizedBox(height: 4),
              // 台词
              Text(
                widget.text,
                style: TextStyle(
                  fontSize: fontSize,
                  color: Colors.white,
                  height: 1.4,
                ),
                maxLines: 6,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
