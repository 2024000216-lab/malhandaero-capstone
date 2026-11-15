import 'package:flutter/material.dart';

import '../theme.dart';

/// 켜짐/꺼짐 표시. 색이 아니라 모양(꽉 참/테두리)과 글자로 구분한다.
class OnOffPill extends StatelessWidget {
  final bool on;
  const OnOffPill({super.key, required this.on});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 96,
      height: 52,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: on ? AppColors.ink : Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: on ? null : Border.all(color: AppColors.border, width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (on) const Icon(Icons.check_rounded, size: 20, color: Colors.white),
          Text(
            on ? '켜짐' : '꺼짐',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: on ? Colors.white : AppColors.sub,
            ),
          ),
        ],
      ),
    );
  }
}

/// 작은 글자 표시 (▶ 다음 일정, 끝남)
class TextTag extends StatelessWidget {
  final String text;
  final bool filled;
  final Color color;
  const TextTag({super.key, required this.text, this.filled = false, this.color = AppColors.ink});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: filled ? color : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: filled ? null : Border.all(color: color, width: 2),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w800,
          color: filled ? Colors.white : color,
        ),
      ),
    );
  }
}
