import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:hugeicons/hugeicons.dart';

import '../providers/dashboard_provider.dart';
import '../theme/app_theme.dart';

/// Glassmorphic top status header optimized for 2021 Sigra R Deluxe.
class StatusHeader extends StatefulWidget {
  const StatusHeader({super.key});

  @override
  State<StatusHeader> createState() => _StatusHeaderState();
}

class _StatusHeaderState extends State<StatusHeader> {
  late Timer _clockTimer;
  String _timeString = '';

  @override
  void initState() {
    super.initState();
    _updateTime();
    _clockTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _updateTime(),
    );
  }

  void _updateTime() {
    final DateTime now = DateTime.now();
    final int hour = now.hour > 12 ? now.hour - 12 : (now.hour == 0 ? 12 : now.hour);
    final String amPm = now.hour >= 12 ? 'pm' : 'am';
    final String minute = now.minute.toString().padLeft(2, '0');
    setState(() {
      _timeString = '$hour:$minute$amPm';
    });
  }

  @override
  void dispose() {
    _clockTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DashboardProvider>(
      builder: (BuildContext context, DashboardProvider p, _) {
        return Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.only(top: 12.0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(32),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.15),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ── Left: Engine Load badge ──
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: p.engineLoad < 80
                              ? AppTheme.accentCyan.withValues(alpha: 0.2)
                              : AppTheme.alertRed.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.memory_rounded,
                              size: 14.0,
                              color: p.engineLoad < 80
                                  ? AppTheme.accentCyan
                                  : AppTheme.alertRed,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${p.engineLoad}%',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: p.engineLoad < 80
                                    ? AppTheme.accentCyan
                                    : AppTheme.alertRed,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      // ── Center: Time ──
                      Text(
                        _timeString,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(width: 16),
                      // ── Connection badge ──
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: p.isConnected
                              ? AppTheme.successGreen.withValues(alpha: 0.2)
                              : AppTheme.alertRed.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            HugeIcon(
                              icon: HugeIcons.strokeRoundedPlug01,
                              size: 14.0,
                              color: p.isConnected
                                  ? AppTheme.successGreen
                                  : AppTheme.alertRed,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              p.isConnected ? 'OBD' : 'OFF',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: p.isConnected
                                    ? AppTheme.successGreen
                                    : AppTheme.alertRed,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
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


