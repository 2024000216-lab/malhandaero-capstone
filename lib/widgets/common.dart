import 'package:flutter/material.dart';

import '../theme.dart';

/// 화면마다 1개만 쓰는 파란 주 버튼. onPressed가 null이면
/// 회색으로 바뀌고 [disabledLabel]로 "무엇을 하면 눌리는지" 알려준다.
class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final String? disabledLabel;
  final double height;

  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.disabledLabel,
    this.height = 64,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return SizedBox(
      width: double.infinity,
      height: height,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.disabledBg,
          disabledForegroundColor: AppColors.disabledFg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: TextStyle(
            fontSize: enabled ? 21 : 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        child: Text(enabled ? label : (disabledLabel ?? label),
            textAlign: TextAlign.center),
      ),
    );
  }
}

/// 테두리 버튼 (보조 행동)
class SecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color color;
  final double height;
  final bool bold;

  const SecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.color = AppColors.text,
    this.height = 56,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = color == AppColors.text ? AppColors.border : color;
    return SizedBox(
      width: double.infinity,
      height: height,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: borderColor, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: TextStyle(
              fontSize: 18, fontWeight: bold ? FontWeight.w700 : FontWeight.w500),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[Icon(icon, size: 22), const SizedBox(width: 8)],
            Flexible(child: Text(label, textAlign: TextAlign.center)),
          ],
        ),
      ),
    );
  }
}

/// 화면 위쪽 왼편의 글자 버튼 ("뒤로", "취소", "그만하기")
class TopTextButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final bool withArrow;

  const TopTextButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.withArrow = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: AppColors.text,
        minimumSize: const Size(64, 48),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (withArrow) const Icon(Icons.chevron_left, size: 26),
          Text(label),
        ],
      ),
    );
  }
}

/// 크게 누르는 선택지 묶음 (시간·날짜 고르기)
class ChoiceGrid extends StatelessWidget {
  final List<String> options;
  final String? selected;
  final ValueChanged<String> onSelect;
  final int columns;

  const ChoiceGrid({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelect,
    this.columns = 3,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      const gap = 8.0;
      final w = (c.maxWidth - gap * (columns - 1)) / columns;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (final o in options)
            SizedBox(
              width: w,
              height: 56,
              child: _choice(o, o == selected),
            ),
        ],
      );
    });
  }

  Widget _choice(String label, bool on) {
    return OutlinedButton(
      onPressed: () => onSelect(label),
      style: OutlinedButton.styleFrom(
        padding: EdgeInsets.zero,
        backgroundColor: on ? AppColors.text : Colors.white,
        foregroundColor: on ? Colors.white : AppColors.text,
        side: BorderSide(
            color: on ? AppColors.text : AppColors.border, width: on ? 2 : 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w500),
      ),
      child: Text(label, textAlign: TextAlign.center),
    );
  }
}

/// "네, 알려주세요 / 아니요" 처럼 둘 중 하나 고르기
class YesNo extends StatelessWidget {
  final bool value;
  final String yes;
  final String no;
  final ValueChanged<bool> onChanged;

  const YesNo({
    super.key,
    required this.value,
    required this.onChanged,
    this.yes = '네, 알려주세요',
    this.no = '아니요',
  });

  @override
  Widget build(BuildContext context) {
    Widget btn(String label, bool on, bool v) => Expanded(
          child: SizedBox(
            height: 56,
            child: OutlinedButton(
              onPressed: () => onChanged(v),
              style: OutlinedButton.styleFrom(
                backgroundColor: on ? AppColors.primary : Colors.white,
                foregroundColor: on ? Colors.white : AppColors.text,
                side: BorderSide(
                    color: on ? AppColors.primary : AppColors.border,
                    width: on ? 2 : 1.5),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                textStyle:
                    const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
              child: Text(label),
            ),
          ),
        );
    return Row(children: [
      btn(yes, value, true),
      const SizedBox(width: 8),
      btn(no, !value, false),
    ]);
  }
}

/// "언제 | 10월 23일 금요일" 한 줄
class InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool last;
  final bool muted;

  const InfoRow({
    super.key,
    required this.label,
    required this.value,
    this.last = false,
    this.muted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 60),
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: last
            ? null
            : const Border(bottom: BorderSide(color: Color(0xFFE6E6E2))),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 68,
            child: Text(label,
                style: const TextStyle(fontSize: 16, color: AppColors.sub)),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: muted ? FontWeight.w400 : FontWeight.w700,
                color: muted ? AppColors.sub : AppColors.text,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 테두리 있는 묶음 상자
class Box extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const Box({super.key, required this.child, this.padding = const EdgeInsets.symmetric(horizontal: 18, vertical: 4)});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.lightBorder, width: 1.5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: child,
    );
  }
}

/// 크고 동그란 주 버튼 (마이크 / 녹음 끝내기)
class RoundActionButton extends StatelessWidget {
  final VoidCallback onPressed;
  final Widget child;
  final String semanticLabel;
  final double size;

  const RoundActionButton({
    super.key,
    required this.onPressed,
    required this.child,
    required this.semanticLabel,
    this.size = 112,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          // 아래쪽 그림자로 "눌리는 물건"처럼 보이게
          boxShadow: [BoxShadow(color: AppColors.primaryShadow, offset: Offset(0, 4))],
        ),
        child: Material(
          color: AppColors.primary,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: Center(child: child),
          ),
        ),
      ),
    );
  }
}

/// 큰 글씨 확인 창. 안전한 선택(취소 쪽)이 파란 주 버튼.
/// 위험한 선택을 누르면 true.
Future<bool> showBigConfirm(
  BuildContext context, {
  required String title,
  required String message,
  required String safeLabel,
  required String dangerLabel,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            Text(message,
                style: const TextStyle(
                    fontSize: 18, color: AppColors.sub, height: 1.5)),
            const SizedBox(height: 20),
            PrimaryButton(
              label: safeLabel,
              height: 60,
              onPressed: () => Navigator.pop(context, false),
            ),
            const SizedBox(height: 8),
            SecondaryButton(
              label: dangerLabel,
              color: AppColors.danger,
              bold: true,
              onPressed: () => Navigator.pop(context, true),
            ),
          ],
        ),
      ),
    ),
  );
  return result ?? false;
}

/// 큰 글씨 한 줄 입력 창. 취소하면 null.
Future<String?> showTextInput(
  BuildContext context, {
  required String title,
  String? initial,
  String? hint,
}) {
  final controller = TextEditingController(text: initial ?? '');
  return showDialog<String>(
    context: context,
    builder: (context) => Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),
            BigTextField(controller: controller, hint: hint, autofocus: true),
            const SizedBox(height: 18),
            PrimaryButton(
              label: '확인',
              height: 60,
              onPressed: () => Navigator.pop(context, controller.text.trim()),
            ),
            const SizedBox(height: 8),
            SecondaryButton(
                label: '취소', onPressed: () => Navigator.pop(context)),
          ],
        ),
      ),
    ),
  );
}

class BigTextField extends StatelessWidget {
  final TextEditingController controller;
  final String? hint;
  final bool autofocus;
  final ValueChanged<String>? onChanged;

  const BigTextField({
    super.key,
    required this.controller,
    this.hint,
    this.autofocus = false,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder b(Color c, double w) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: c, width: w));
    return TextField(
      controller: controller,
      autofocus: autofocus,
      onChanged: onChanged,
      style: const TextStyle(fontSize: 20),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.disabledFg),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        enabledBorder: b(AppColors.border, 2),
        focusedBorder: b(AppColors.primary, 2.5),
      ),
    );
  }
}

/// 테두리 상자 안에 쓰는 제목 (1. 무엇을 하나요?)
class QuestionLabel extends StatelessWidget {
  final String text;
  final String? note;
  const QuestionLabel(this.text, {super.key, this.note});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text.rich(TextSpan(children: [
        TextSpan(
            text: text,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
        if (note != null)
          TextSpan(
              text: '  $note',
              style: const TextStyle(fontSize: 16, color: AppColors.sub)),
      ])),
    );
  }
}
