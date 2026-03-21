import 'package:flutter/material.dart';

class BookBody extends StatelessWidget {
  final String bookName;

  const BookBody({super.key, required this.bookName});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(children: _buildBookRowChildren(context, bookName, colors));
  }

  List<Widget> _buildBookRowChildren(
    BuildContext context,
    String bookName,
    ColorScheme colors,
  ) {
    final isRtl = Directionality.of(context) == TextDirection.rtl;

    final spine = Container(
      width: 10,
      decoration: BoxDecoration(
        color: colors.primary,
        borderRadius: isRtl
            ? const BorderRadius.only(
                topRight: Radius.circular(6),
                bottomRight: Radius.circular(6),
              )
            : const BorderRadius.only(
                topLeft: Radius.circular(6),
                bottomLeft: Radius.circular(6),
              ),
      ),
    );

    final pageThickness = Container(
      width: 4,
      color: colors.surfaceContainerHighest.withAlpha(40),
    );

    final cover = Expanded(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [colors.primary, colors.primaryContainer],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: isRtl
              ? const BorderRadius.only(
                  topLeft: Radius.circular(6),
                  bottomLeft: Radius.circular(6),
                )
              : const BorderRadius.only(
                  topRight: Radius.circular(6),
                  bottomRight: Radius.circular(6),
                ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 6,
              child: Container(
                decoration: BoxDecoration(
                  color: colors.onSurfaceVariant.withAlpha(38),
                  borderRadius: isRtl
                      ? const BorderRadius.only(topLeft: Radius.circular(6))
                      : const BorderRadius.only(topRight: Radius.circular(6)),
                ),
              ),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  bookName,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: colors.onPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return [spine, pageThickness, cover];
  }
}
