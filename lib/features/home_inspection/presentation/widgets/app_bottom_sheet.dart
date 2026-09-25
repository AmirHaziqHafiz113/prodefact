import 'package:flutter/material.dart';

import '../../../../app/theme/design_system.dart';

/// Shows a modal bottom sheet whose actions can never end up hidden
/// (QA #15): below the Android navigation bar, the iPhone home
/// indicator, the keyboard, or the bottom of a small screen, including
/// at large text sizes.
///
/// Always scroll-controlled (so the sheet may grow to the screen height
/// instead of Flutter's default 9/16 cap) and kept clear of the status
/// bar via `useSafeArea`. Lay the content out with [AppSheetFrame].
Future<T?> showAppBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: builder,
  );
}

/// The standard body of an [showAppBottomSheet] sheet.
///
/// [child] scrolls when it doesn't fit. [actions], if given, are pinned
/// below it and stay on screen at all times: the scrolling area shrinks
/// first, whether the space is taken by the keyboard, a short screen, or
/// larger text. Bottom system insets (navigation bar, home indicator)
/// and the keyboard are both kept clear.
///
/// Set [scrollable] to false when [child] manages its own scrolling
/// (e.g. a `DraggableScrollableSheet` or a list with `Expanded`).
class AppSheetFrame extends StatelessWidget {
  const AppSheetFrame({
    super.key,
    required this.child,
    this.actions,
    this.scrollable = true,
    this.padding = const EdgeInsets.fromLTRB(
      AppSpacing.lg,
      AppSpacing.md,
      AppSpacing.lg,
      AppSpacing.lg,
    ),
  });

  final Widget child;
  final Widget? actions;
  final bool scrollable;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final body = scrollable ? SingleChildScrollView(child: child) : child;
    return Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: padding,
          child: actions == null
              ? body
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Flexible(child: body),
                    const SizedBox(height: AppSpacing.md),
                    actions!,
                  ],
                ),
        ),
      ),
    );
  }
}
