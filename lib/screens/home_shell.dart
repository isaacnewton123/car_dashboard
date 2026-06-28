import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:glassmorphism/glassmorphism.dart';
import 'package:hugeicons/hugeicons.dart';

import '../models/nav_page.dart';
import '../providers/dashboard_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/status_header.dart';
import 'app_launcher_page.dart';
import 'assistant_page.dart';
import 'dashboard_page.dart';
import 'diagnostics_page.dart';
import 'media_page.dart';
import 'performance_page.dart';
import 'settings_page.dart';
import 'trip_page.dart';

/// Home shell — Tesla-inspired layout with:
///   • Top status bar (P R N D, battery, time, temp)
///   • Content area (IndexedStack of 10 pages)
///   • Bottom dock (car icon + temp | nav icons | temp + volume)
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _currentIndex = 0;
  int _lastMainPageIndex = 0;
  bool _isUiVisible = true;
  Timer? _hideTimer;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentIndex);
    _startHideTimer();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _hideTimer?.cancel();
    super.dispose();
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _isUiVisible) {
        setState(() {
          _isUiVisible = false;
        });
      }
    });
  }

  int _toPageViewIndex(int navIndex) {
    if (navIndex < 6) return navIndex;
    if (navIndex == 7) return 6;
    return 0; // Fallback
  }

  void _setPage(int navIndex) {
    if (_currentIndex == navIndex) return;
    
    final wasApps = _currentIndex == 6;
    if (!wasApps) {
      _lastMainPageIndex = _currentIndex;
    }

    setState(() => _currentIndex = navIndex);

    if (navIndex != 6) {
      if (wasApps) {
        _pageController.jumpToPage(_toPageViewIndex(navIndex));
      } else {
        _pageController.animateToPage(
          _toPageViewIndex(navIndex),
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutCubic,
        );
      }
    }
  }

  void _nextPage() {
    int next = _currentIndex + 1;
    if (next == 6) next = 7;
    if (next > 7) next = 0;
    _setPage(next);
  }

  void _previousPage() {
    int prev = _currentIndex - 1;
    if (prev == 6) prev = 5;
    if (prev < 0) prev = 7;
    _setPage(prev);
  }

  void _showApps() {
    _setPage(6);
  }

  void _showNavbar() {
    setState(() {
      _isUiVisible = true;
    });
    _startHideTimer();
  }

  final Map<int, Offset> _activePointers = {};
  bool _hasTriggeredGesture = false;
  Offset _twoFingerStart = Offset.zero;

  Offset _getMidpoint(Iterable<Offset> offsets) {
    final list = offsets.toList();
    return Offset(
      (list[0].dx + list[1].dx) / 2,
      (list[0].dy + list[1].dy) / 2,
    );
  }

  static const List<Widget> _mainPages = [
    DashboardPage(),
    AssistantPage(),
    MediaPage(),
    TripPage(),
    PerformancePage(),
    DiagnosticsPage(),
    SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/images/wallpaper.png'),
          fit: BoxFit.cover,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
      body: Listener(
        onPointerDown: (event) {
          _activePointers[event.pointer] = event.position;
          if (_activePointers.length == 2) {
            _hasTriggeredGesture = false;
            _twoFingerStart = _getMidpoint(_activePointers.values);
          }
        },
        onPointerMove: (event) {
          if (_activePointers.containsKey(event.pointer)) {
            _activePointers[event.pointer] = event.position;
          }

          if (_activePointers.length == 2 && !_hasTriggeredGesture) {
            final currentMidpoint = _getMidpoint(_activePointers.values);
            final dx = currentMidpoint.dx - _twoFingerStart.dx;
            final dy = currentMidpoint.dy - _twoFingerStart.dy;

            const threshold = 100.0; // swipe threshold
            if (dx.abs() > threshold || dy.abs() > threshold) {
              _hasTriggeredGesture = true;
              if (dx.abs() > dy.abs()) {
                // Horizontal
                if (dx > 0) {
                  _previousPage(); // Swiped right -> go to previous
                } else {
                  _nextPage(); // Swiped left -> go to next
                }
              } else {
                // Vertical
                if (dy > 0) {
                  // Swiped down
                  if (_currentIndex == 6) {
                    _setPage(_lastMainPageIndex); // Close apps
                  } else {
                    _showNavbar(); // Show navbar if on normal page
                  }
                } else {
                  _showApps(); // Swiped up -> show apps
                }
              }
            }
          }
        },
        onPointerUp: (event) {
          _activePointers.remove(event.pointer);
        },
        onPointerCancel: (event) {
          _activePointers.remove(event.pointer);
        },
        child: Stack(
          children: [
            // ── Middle: Main Pages (Horizontal Swipe) ──
            Positioned.fill(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: _mainPages,
              ),
            ),

            // ── Apps Overlay (Vertical Slide) ──
            Positioned.fill(
              child: AnimatedSlide(
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeOutCubic,
                offset: _currentIndex == 6 ? Offset.zero : const Offset(0, 1.2),
                child: const AppLauncherPage(),
              ),
            ),

            // ── Top: Tesla status header (floating) ──
            AnimatedPositioned(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeInOutBack,
              top: _isUiVisible ? 0 : -100,
              left: 0,
              right: 0,
              child: const SafeArea(
                bottom: false,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: StatusHeader(),
                ),
              ),
            ),

            // ── Bottom: Tesla-style dock (floating) ──
            AnimatedPositioned(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeInOutBack,
              bottom: _isUiVisible ? 0 : -150,
              left: 0,
              right: 0,
              child: SafeArea(
                top: false,
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: _TeslaDock(
                    currentIndex: _currentIndex,
                    onTabSelected: (int index) {
                      _startHideTimer();
                      _setPage(index);
                    },
                  ),
                ),
              ),
            ),
            // ── Floating Menu Button (Only to SHOW) ──
            if (!_isUiVisible)
              Positioned(
                left: 24,
                bottom: 24,
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _isUiVisible = true;
                    });
                    _startHideTimer();
                  },
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppTheme.glassFill,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.glassBorder),
                  ),
                  child: Icon(
                    _isUiVisible ? Icons.keyboard_arrow_down_rounded : Icons.menu_rounded,
                    color: AppTheme.accentCyan,
                    size: 32,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

// =============================================================================
// Tesla-Style Bottom Dock
// =============================================================================
//
// Layout mirrors the Tesla Model 3 footer:
// ┌──────────────────────────────────────────────────────────────────────────┐
// │ 🚗  < 72 >  │  📞 📻 🔵 🎵 📷 🎬 📱  │  < 72 >  🔊               │
// └──────────────────────────────────────────────────────────────────────────┘

class _TeslaDock extends StatelessWidget {
  const _TeslaDock({
    required this.currentIndex,
    required this.onTabSelected,
  });

  final int currentIndex;
  final ValueChanged<int> onTabSelected;

  @override
  Widget build(BuildContext context) {
    final List<NavPage> leftPages = [NavPage.assistant, NavPage.media, NavPage.trip];
    final List<NavPage> rightPages = [NavPage.performance, NavPage.diagnostics, NavPage.settings];
    final int launcherIndex = NavPage.values.indexOf(NavPage.appLauncher);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0, left: 16.0, right: 16.0),
      child: SizedBox(
        height: AppTheme.dockHeight,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            // ── Glassmorphic Background with Notch ──
            Positioned.fill(
              child: ClipPath(
                clipper: _DockNotchClipper(),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withValues(alpha: 0.10),
                          Colors.white.withValues(alpha: 0.05),
                        ],
                        stops: const [0.1, 1],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            
            // ── Notch Border ──
            Positioned.fill(
              child: CustomPaint(
                painter: _DockNotchPainter(),
              ),
            ),

            // ── Dock Icons ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  // ── Left: Car icon ──
                  _DockCarIcon(
                    isActive: currentIndex == 0,
                    onTap: () => onTabSelected(0),
                  ),

                  // ── Left Navigation Icons ──
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: leftPages.map((page) {
                        return _DockNavIcon(
                          page: page,
                          isActive: page.index == currentIndex,
                          onTap: () => onTabSelected(page.index),
                        );
                      }).toList(),
                    ),
                  ),

                  // ── Center Notch Space ──
                  const SizedBox(width: 80),

                  // ── Right Navigation Icons ──
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: rightPages.map((page) {
                        return _DockNavIcon(
                          page: page,
                          isActive: page.index == currentIndex,
                          onTap: () => onTabSelected(page.index),
                        );
                      }).toList(),
                    ),
                  ),

                  // ── Right: Volume Control ──
                  _VolumeControl(),
                ],
              ),
            ),

            // ── Center Floating Apps Button ──
            Positioned(
              top: -24,
              child: GestureDetector(
                onTap: () => onTabSelected(launcherIndex),
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: currentIndex == launcherIndex ? AppTheme.accentCyan : const Color(0xFF1E1E1E),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: (currentIndex == launcherIndex ? AppTheme.accentCyan : Colors.black).withValues(alpha: 0.4),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                    border: Border.all(
                      color: currentIndex == launcherIndex ? Colors.white : AppTheme.glassBorder,
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    Icons.apps_rounded,
                    size: 32,
                    color: currentIndex == launcherIndex ? Colors.black : Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DockNotchClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    return Path()
      ..addPath(
        AutomaticNotchedShape(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          const CircleBorder(),
        ).getOuterPath(
          Offset.zero & size,
          Rect.fromCenter(
            center: Offset(size.width / 2, 0),
            width: 84, // Slightly wider than the 64px FAB to create a gap
            height: 84,
          ),
        ),
        Offset.zero,
      );
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _DockNotchPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = _DockNotchClipper().getClip(size);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: 0.5),
          Colors.white.withValues(alpha: 0.1),
        ],
      ).createShader(Offset.zero & size);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ---------------------------------------------------------------------------
// Dock Car Icon (replaces Dashboard tab)
// ---------------------------------------------------------------------------

class _DockCarIcon extends StatelessWidget {
  const _DockCarIcon({required this.isActive, required this.onTap});
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(6),
        child: HugeIcon(
          icon: HugeIcons.strokeRoundedCar01,
          size: 24.0,
          color: isActive
              ? AppTheme.textPrimary
              : AppTheme.textSecondary.withValues(alpha: 0.6),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Dock Navigation Icon
// ---------------------------------------------------------------------------

class _DockNavIcon extends StatelessWidget {
  const _DockNavIcon({
    required this.page,
    required this.isActive,
    required this.onTap,
  });

  final NavPage page;
  final bool isActive;
  final VoidCallback onTap;

  /// Get icon color per nav type, matching Tesla style.
  Color _iconColor() {
    if (!isActive) return AppTheme.textSecondary.withValues(alpha: 0.5);
    switch (page) {
      case NavPage.dashboard:
        return AppTheme.textPrimary;
      case NavPage.assistant:
        return AppTheme.accentCyan;
      case NavPage.media:
        return const Color(0xFF1DB954); // Spotify green
      case NavPage.diagnostics:
        return AppTheme.alertAmber;
      case NavPage.settings:
        return AppTheme.textPrimary;
      default:
        return AppTheme.textPrimary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Tooltip(
        message: page.label,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(6),
          decoration: isActive
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: _iconColor().withValues(alpha: 0.1),
                )
              : null,
          child: HugeIcon(
            icon: page.icon,
            size: 22.0,
            color: _iconColor(),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Volume Control
// ---------------------------------------------------------------------------

class _VolumeControl extends StatelessWidget {
  void _showVolumeModal(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (context, anim1, anim2) {
        return const _VolumeModalContent();
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: anim1,
            curve: Curves.easeOutQuart,
          )),
          child: FadeTransition(
            opacity: anim1,
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showVolumeModal(context),
      behavior: HitTestBehavior.opaque,
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: HugeIcon(
          icon: HugeIcons.strokeRoundedVolumeHigh,
          size: 24.0,
          color: AppTheme.textPrimary,
        ),
      ),
    );
  }
}

class _VolumeModalContent extends StatefulWidget {
  const _VolumeModalContent();

  @override
  State<_VolumeModalContent> createState() => _VolumeModalContentState();
}

class _VolumeModalContentState extends State<_VolumeModalContent> {
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _resetHideTimer();
  }

  void _resetHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    });
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomRight,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 100.0, right: 24.0),
        child: Material(
          color: Colors.transparent,
          child: GlassmorphicContainer(
            width: 60,
            height: 200,
            borderRadius: 20,
            blur: 20,
            alignment: Alignment.center,
            border: 1,
            linearGradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.15),
                Colors.white.withValues(alpha: 0.05),
              ],
            ),
            borderGradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.5),
                Colors.white.withValues(alpha: 0.1),
              ],
            ),
            child: Consumer<DashboardProvider>(
              builder: (context, prov, _) {
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 12),
                    const HugeIcon(
                      icon: HugeIcons.strokeRoundedVolumeHigh,
                      size: 20.0,
                      color: AppTheme.textPrimary,
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: RotatedBox(
                        quarterTurns: 3,
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 4.0,
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8.0),
                            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16.0),
                          ),
                          child: Slider(
                            value: prov.volume.toDouble(),
                            min: 0,
                            max: 100,
                            activeColor: AppTheme.accentCyan,
                            inactiveColor: AppTheme.textSecondary.withValues(alpha: 0.2),
                            onChangeStart: (_) => _hideTimer?.cancel(),
                            onChanged: (val) {
                              prov.setVolume(val.toInt());
                            },
                            onChangeEnd: (_) => _resetHideTimer(),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${prov.volume}',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
