import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Minimal HTML-to-widgets renderer for the storefront's static page
/// content (`h1`–`h3`, `p`, `ul`/`ol`/`li`, inline `strong`/`b`/`em`/`i`,
/// `br`) — enough for CMS copy without pulling in a full HTML engine.
class SimpleHtml extends StatelessWidget {
  final String html;
  const SimpleHtml({super.key, required this.html});

  @override
  Widget build(BuildContext context) {
    final blocks = _splitBlocks(html);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final block in blocks) ...[
          _buildBlock(block),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _buildBlock(_Block block) {
    switch (block.type) {
      case _BlockType.heading:
        return Text(
          block.text,
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.inkStrong),
        );
      case _BlockType.listItem:
        return Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('•  ', style: TextStyle(color: AppColors.body, fontSize: 14)),
              Expanded(child: Text(block.text, style: TextStyle(color: AppColors.body, fontSize: 14, height: 1.5))),
            ],
          ),
        );
      case _BlockType.paragraph:
        return Text(block.text, style: TextStyle(color: AppColors.body, fontSize: 14, height: 1.6));
    }
  }

  List<_Block> _splitBlocks(String raw) {
    final blocks = <_Block>[];
    final tagPattern = RegExp(
      r'<(h[1-3]|p|li)[^>]*>(.*?)<\/\1>',
      caseSensitive: false,
      dotAll: true,
    );
    final matches = tagPattern.allMatches(raw);

    if (matches.isEmpty) {
      final text = _stripTags(raw);
      if (text.isNotEmpty) blocks.add(_Block(_BlockType.paragraph, text));
      return blocks;
    }

    for (final match in matches) {
      final tag = match.group(1)!.toLowerCase();
      final text = _stripTags(match.group(2)!);
      if (text.isEmpty) continue;
      final type = tag == 'li'
          ? _BlockType.listItem
          : tag.startsWith('h')
              ? _BlockType.heading
              : _BlockType.paragraph;
      blocks.add(_Block(type, text));
    }
    return blocks;
  }

  String _stripTags(String value) {
    var text = value.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
    text = text.replaceAll(RegExp(r'<[^>]+>'), '');
    text = text
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>');
    return text.trim();
  }
}

enum _BlockType { heading, paragraph, listItem }

class _Block {
  final _BlockType type;
  final String text;
  _Block(this.type, this.text);
}
