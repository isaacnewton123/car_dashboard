import 'package:hugeicons/hugeicons.dart';

/// Identifies each page in the bottom navigation dock.
///
/// Each variant carries the icon and label metadata needed
/// to render the dock item.
enum NavPage {
  dashboard(icon: HugeIcons.strokeRoundedDashboardCircle, label: 'Dashboard'),
  assistant(icon: HugeIcons.strokeRoundedMic01, label: 'Assistant'),
  trip(icon: HugeIcons.strokeRoundedAnalytics01, label: 'Trip'),
  performance(icon: HugeIcons.strokeRoundedRocket01, label: 'Performance'),
  diagnostics(icon: HugeIcons.strokeRoundedWrench01, label: 'Diagnostics'),
  appLauncher(icon: HugeIcons.strokeRoundedGridView, label: 'Apps'),
  settings(icon: HugeIcons.strokeRoundedSettings01, label: 'Settings');

  const NavPage({required this.icon, required this.label});

  /// The HugeIcon displayed in the dock.
  final dynamic icon;

  /// Short label for accessibility / tooltips.
  final String label;
}
