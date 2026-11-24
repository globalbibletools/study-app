import 'package:material_ui/material_ui.dart';

class ReadingPlanAppBar extends StatelessWidget implements PreferredSizeWidget {
  const ReadingPlanAppBar({
    super.key,
    required this.title,
    this.onBack,
    this.actions = const <Widget>[],
    this.centerTitle = true,
    this.titleSpacing,
  });

  final Widget title;
  final VoidCallback? onBack;
  final List<Widget> actions;
  final bool centerTitle;
  final double? titleSpacing;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final baseTitleStyle =
        Theme.of(context).appBarTheme.titleTextStyle ??
        Theme.of(context).textTheme.titleLarge;
    return AppBar(
      primary: false,
      automaticallyImplyLeading: false,
      centerTitle: centerTitle,
      titleSpacing: titleSpacing,
      toolbarHeight: kToolbarHeight,
      leadingWidth: 56,
      actionsPadding: const EdgeInsets.only(right: 4),
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: baseTitleStyle?.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
      leading: onBack == null
          ? null
          : IconButton(
              icon: const Icon(Icons.arrow_back),
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              onPressed: onBack,
            ),
      title: title,
      actions: actions,
    );
  }
}
