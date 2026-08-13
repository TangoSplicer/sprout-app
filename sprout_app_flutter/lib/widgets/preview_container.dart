import 'package:flutter/material.dart';

import '../theme/sprout_theme.dart';

class PreviewContainer extends StatelessWidget {
  final Widget child;

  const PreviewContainer({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 520;
        final width = isCompact ? constraints.maxWidth : 390.0;
        final height = isCompact
            ? constraints.maxHeight
            : constraints.maxHeight.clamp(420.0, 720.0);

        return Center(
          child: SizedBox(
            width: width,
            height: height,
            child: DecoratedBox(
              key: const Key('sprout-preview-frame'),
              decoration: BoxDecoration(
                color: SproutTheme.ink,
                borderRadius: BorderRadius.circular(isCompact ? 20 : 30),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x24000000),
                    blurRadius: 24,
                    offset: Offset(0, 12),
                  ),
                ],
              ),
              child: Padding(
                padding: EdgeInsets.all(isCompact ? 4 : 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(isCompact ? 16 : 24),
                  child: ColoredBox(
                    color: Theme.of(context).colorScheme.surface,
                    child: child,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
