import 'package:flutter/material.dart';

class CodeDictionaryTitle extends StatelessWidget {
  const CodeDictionaryTitle({
    super.key,
    this.text = 'Codictionary',
    this.fontSize =
        90, // NРїС—Р…?РїС—Р…?РїС—Р…???РїС—Р…NРїС—Р… N?NРїС—Р…??NРїС—Р…NРїС—Р…?РїС—Р… ?? AppBar
    this.strokeWidth = 3.0,
    this.strokeColor = const Color(0xCC000000),
    this.fillColor = Colors
        .white, // NРїС—Р…???РїС—Р…NРїС—Р… ?РїС—Р…?РїС—Р…?РїС—Р…???????? NРїС—Р…?РїС—Р…??N?NРїС—Р…?РїС—Р…
    this.imagePath = 'assets/images/cody.png',
    this.gap =
        6.0, // ??NРїС—Р…N?NРїС—Р…N??? ???РїС—Р…?РїС—Р…??N? ???РїС—Р…N?????NРїС—Р…???? ?? NРїС—Р…?РїС—Р…??N?NРїС—Р…????
    this.fontFamily, // 'CodictionaryCartoon' ?РїС—Р…N??РїС—Р…?? ?????РїС—Р…?РїС—Р…?????РїС—Р… N?NРїС—Р…??NРїС—Р…NРїС—Р…
  });

  final String text;
  final double fontSize;
  final double strokeWidth;
  final Color strokeColor;
  final Color fillColor;
  final String imagePath;
  final double gap;
  final String? fontFamily;

  @override
  Widget build(BuildContext context) {
    // ??NРїС—Р…N???NРїС—Р…?РїС—Р… ???РїС—Р…NРїС—Р…NРїС—Р…???????? aРїС—Р…? ??NРїС—Р…N???NРїС—Р…?РїС—Р… NРїС—Р…?РїС—Р…??N?NРїС—Р…?РїС—Р… (NРїС—Р…N?NРїС—Р…N? ?РїС—Р…???РїС—Р…N?N??РїС—Р…, NРїС—Р…NРїС—Р…???РїС—Р…NРїС—Р… ?????РїС—Р…N??РїС—Р…?РїС—Р…N????? N????????РїС—Р…?РїС—Р…??)
    final double imageHeight = fontSize * 1.15;

    final TextStyle base = TextStyle(
      fontSize: fontSize,
      height:
          1.0, // ???РїС—Р…??NРїС—Р…???РїС—Р…?РїС—Р… ????N??РїС—Р…?????РїС—Р…
      letterSpacing: 6,
      fontFamily:
          fontFamily, // 'CodictionaryCartoon' ?РїС—Р…N??РїС—Р…?? ?????????РїС—Р…NZNРїС—Р…???РїС—Р… N?NРїС—Р…??NРїС—Р…NРїС—Р…
      fontWeight: FontWeight.w700,
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(imagePath, height: imageHeight),
        SizedBox(width: gap),
        Stack(
          children: [
            Text(
              text,
              style: base.copyWith(
                foreground: Paint()
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = strokeWidth
                  ..color = strokeColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.fade,
              softWrap: false,
            ),
            // ?РїС—Р…?РїС—Р…?РїС—Р…???????РїС—Р…
            Text(
              text,
              style: base.copyWith(color: fillColor),
              maxLines: 1,
              overflow: TextOverflow.fade,
              softWrap: false,
            ),
          ],
        ),
      ],
    );
  }
}
