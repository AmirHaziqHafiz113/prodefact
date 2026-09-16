import 'package:flutter/material.dart';

/// A small, semantic status indicator — always icon + label, never
/// color alone, so it stays meaningful without relying on color
/// perception. Used for sync state, completion state, review outcome,
/// etc. across the app.
class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.label,
    required this.icon,
    required this.foreground,
    required this.background,
    this.dense = false,
  });

  final String label;
  final IconData icon;
  final Color foreground;
  final Color background;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 8 : 10,
        vertical: dense ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: dense ? 13 : 15, color: foreground),
          const SizedBox(width: 5),
          // Flexible (not a bare Text) so that when a parent gives this
          // pill less width than its label naturally wants (e.g. a
          // ListTile-style row squeezed between a leading control and
          // trailing action buttons), the label ellipsizes instead of
          // overflowing past the pill — see
          // `docs/production_readiness.md` ("Area configuration overflow
          // fix"), which this same fix also covers for every other
          // screen that uses `StatusPill`/`SyncStatusPill`.
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: dense ? 11.5 : 12.5,
                fontWeight: FontWeight.w700,
                color: foreground,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
