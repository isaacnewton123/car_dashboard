import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:hugeicons/hugeicons.dart';

import '../models/dtc_code.dart';
import '../providers/dashboard_provider.dart';
import '../services/obd_connection_state.dart';
import '../theme/app_theme.dart';

/// Diagnostics page — DTC codes, OBD log, connection status.
class DiagnosticsPage extends StatelessWidget {
  const DiagnosticsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<DashboardProvider>(
      builder: (BuildContext context, DashboardProvider p, _) {
        final milStatus = p.dtcCodes.isNotEmpty;
        final ert = p.tripTime;

        return Padding(
          padding: const EdgeInsets.all(AppTheme.pagePadding),
          child: Row(
            children: [
              // Left: Vital Signs — scrollable grid
              Expanded(
                flex: 5,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _DiagnosticDataCard(
                              title: 'ECU VOLTAGE',
                              value: '${p.batteryVoltage.toStringAsFixed(1)} V',
                              subtitle: p.isLiveObd ? 'PID 0142' : 'Simulated',
                              icon: HugeIcons.strokeRoundedBatteryFull,
                              valueColor: AppTheme.textPrimary,
                              delay: 100,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _DiagnosticDataCard(
                              title: 'ENGINE RUN TIME',
                              value: p.isLiveObd
                                  ? _formatSeconds(p.timeSinceEngineStart)
                                  : _formatDuration(ert),
                              subtitle: p.isLiveObd ? 'PID 011F' : 'Trip clock',
                              icon: HugeIcons.strokeRoundedTimer02,
                              valueColor: AppTheme.textPrimary,
                              delay: 200,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _DiagnosticDataCard(
                        title: 'MIL STATUS',
                        value: milStatus ? 'ON (CHECK ENGINE)' : 'OFF (SYSTEM OK)',
                        subtitle: 'Malfunction Indicator Lamp',
                        icon: HugeIcons.strokeRoundedEngine,
                        valueColor: milStatus ? AppTheme.alertRed : AppTheme.successGreen,
                        delay: 300,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _DiagnosticDataCard(
                              title: 'CAT TEMP B1S1',
                              value: '${p.catTempB1S1.toStringAsFixed(0)}°C',
                              subtitle: 'Upstream catalyst',
                              icon: HugeIcons.strokeRoundedThermometer,
                              valueColor: p.catTempB1S1 > 800
                                  ? AppTheme.alertRed
                                  : AppTheme.textPrimary,
                              delay: 400,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _DiagnosticDataCard(
                              title: 'CAT TEMP B1S2',
                              value: '${p.catTempB1S2.toStringAsFixed(0)}°C',
                              subtitle: 'Downstream catalyst',
                              icon: HugeIcons.strokeRoundedThermometer,
                              valueColor: p.catTempB1S2 > 800
                                  ? AppTheme.alertRed
                                  : AppTheme.textPrimary,
                              delay: 500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _DiagnosticDataCard(
                              title: 'WARM-UPS',
                              value: '${p.warmupsSinceReset}',
                              subtitle: 'Since ECU reset',
                              icon: HugeIcons.strokeRoundedRepeat,
                              valueColor: AppTheme.textPrimary,
                              delay: 600,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _DiagnosticDataCard(
                              title: 'DIST SINCE RESET',
                              value: '${p.distanceSinceReset} km',
                              subtitle: 'Since ECU reset',
                              icon: HugeIcons.strokeRoundedRoute01,
                              valueColor: AppTheme.textPrimary,
                              delay: 700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _DiagnosticDataCard(
                              title: 'EVAP PURGE',
                              value: '${p.commandedEvapPurge.toStringAsFixed(1)}%',
                              subtitle: 'Commanded purge',
                              icon: HugeIcons.strokeRoundedCloud,
                              valueColor: AppTheme.textPrimary,
                              delay: 800,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _DiagnosticDataCard(
                              title: 'DTC CLEARED',
                              value: _formatMinutes(p.timeSinceDtcCleared),
                              subtitle: 'Time since cleared',
                              icon: HugeIcons.strokeRoundedTime04,
                              valueColor: AppTheme.textPrimary,
                              delay: 900,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Right: DTCs and OBD Log
              Expanded(
                flex: 5,
                child: Column(
                  children: [
                    _ConnectionCard(
                      isConnected: p.isConnected,
                      isLiveObd: p.isLiveObd,
                      obdStatus: p.obdStatus,
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      flex: 3,
                      child: Column(
                        children: [
                          Expanded(child: _DtcList(codes: p.dtcCodes)),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            height: 38,
                            child: OutlinedButton.icon(
                              onPressed: p.clearDtcCodes,
                              icon: const Icon(Icons.delete_outline_rounded, size: 16),
                              label: Text(
                                'CLEAR DTCs',
                                style: GoogleFonts.montserrat(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 2,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.alertAmber,
                                side: BorderSide(
                                  color: AppTheme.alertAmber.withValues(alpha: 0.3),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      flex: 2,
                      child: _ObdLogConsole(log: p.obdLog),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final String h = twoDigits(d.inHours);
    final String m = twoDigits(d.inMinutes.remainder(60));
    final String s = twoDigits(d.inSeconds.remainder(60));
    return "$h:$m:$s";
  }

  String _formatSeconds(int totalSeconds) {
    final int h = totalSeconds ~/ 3600;
    final int m = (totalSeconds % 3600) ~/ 60;
    final int s = totalSeconds % 60;
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    return '${twoDigits(h)}:${twoDigits(m)}:${twoDigits(s)}';
  }

  String _formatMinutes(int totalMinutes) {
    if (totalMinutes < 60) return '${totalMinutes}m';
    final int h = totalMinutes ~/ 60;
    final int m = totalMinutes % 60;
    if (h < 24) return '${h}h ${m}m';
    final int d = h ~/ 24;
    return '${d}d ${h % 24}h';
  }
}

// ---------------------------------------------------------------------------
// Diagnostic Data Card
// ---------------------------------------------------------------------------

class _DiagnosticDataCard extends StatelessWidget {
  const _DiagnosticDataCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.valueColor,
    required this.delay,
  });

  final String title;
  final String value;
  final String subtitle;
  final dynamic icon;
  final Color valueColor;
  final int delay;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withOpacity(0.08),
              width: 1,
            ),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  HugeIcon(icon: icon, color: AppTheme.accentCyan, size: 28),
                  Text(
                    title,
                    style: GoogleFonts.montserrat(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: GoogleFonts.montserrat(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: valueColor,
                      letterSpacing: -1.0,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.montserrat(
                      fontSize: 12,
                      color: AppTheme.accentCyan,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 500.ms, delay: delay.ms);
  }
}

// ---------------------------------------------------------------------------
// Connection Card
// ---------------------------------------------------------------------------

class _ConnectionCard extends StatelessWidget {
  const _ConnectionCard({
    required this.isConnected,
    this.isLiveObd = false,
    this.obdStatus = ObdConnectionStatus.disconnected,
  });
  final bool isConnected;
  final bool isLiveObd;
  final ObdConnectionStatus obdStatus;

  Color _statusDotColor() {
    if (isLiveObd) return AppTheme.successGreen;
    if (obdStatus == ObdConnectionStatus.connecting ||
        obdStatus == ObdConnectionStatus.initializing ||
        obdStatus == ObdConnectionStatus.scanning) {
      return AppTheme.alertAmber;
    }
    if (isConnected) return AppTheme.accentCyan;
    return AppTheme.alertRed;
  }

  String _statusTitle() {
    if (isLiveObd) return 'OBD-II Connected (LIVE)';
    if (obdStatus.isActive) return obdStatus.label;
    if (isConnected) return 'Connected (Simulated)';
    return 'Disconnected';
  }

  String _statusSubtitle() {
    if (isLiveObd) return 'ELM327 • Bluetooth Classic • OBDII';
    if (obdStatus.isActive) return 'Establishing connection...';
    if (isConnected) return 'Mock data • No OBD adapter';
    return 'No OBD-II device detected';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.glassFill,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(color: AppTheme.glassBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _statusDotColor(),
              boxShadow: [
                BoxShadow(
                  color: _statusDotColor().withValues(alpha: 0.5),
                  blurRadius: 6,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _statusTitle(),
                  style: GoogleFonts.montserrat(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Text(
                  _statusSubtitle(),
                  style: GoogleFonts.montserrat(
                    fontSize: 10,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (isLiveObd)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.successGreen.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'LIVE',
                style: GoogleFonts.montserrat(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.successGreen,
                  letterSpacing: 2,
                ),
              ),
            ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms);
  }
}

// ---------------------------------------------------------------------------
// DTC List
// ---------------------------------------------------------------------------

class _DtcList extends StatelessWidget {
  const _DtcList({required this.codes});
  final List<DtcCode> codes;

  Color _severityColor(DtcSeverity severity) {
    switch (severity) {
      case DtcSeverity.error:
        return AppTheme.alertRed;
      case DtcSeverity.warning:
        return AppTheme.alertAmber;
      case DtcSeverity.info:
        return AppTheme.accentCyan;
    }
  }

  String _severityLabel(DtcSeverity severity) {
    switch (severity) {
      case DtcSeverity.error:
        return 'ERROR';
      case DtcSeverity.warning:
        return 'WARN';
      case DtcSeverity.info:
        return 'INFO';
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: codes.length,
      separatorBuilder: (BuildContext ctx, int i) => const SizedBox(height: 6),
      itemBuilder: (BuildContext context, int index) {
        final DtcCode dtc = codes[index];
        final Color color = _severityColor(dtc.severity);
        return Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppTheme.glassFill,
            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            border: Border.all(color: AppTheme.glassBorder),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  dtc.code,
                  style: GoogleFonts.montserrat(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  dtc.description,
                  style: GoogleFonts.montserrat(
                    fontSize: 11,
                    color: AppTheme.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  border: Border.all(
                      color: color.withValues(alpha: 0.3)),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _severityLabel(dtc.severity),
                  style: GoogleFonts.montserrat(
                    fontSize: 8,
                    fontWeight: FontWeight.w600,
                    color: color,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ),
        )
            .animate()
            .fadeIn(duration: 400.ms, delay: (index * 100).ms)
            .slideX(begin: -0.05);
      },
    );
  }
}

// ---------------------------------------------------------------------------
// OBD Log Console
// ---------------------------------------------------------------------------

class _ObdLogConsole extends StatelessWidget {
  const _ObdLogConsole({required this.log});
  final List<String> log;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0D),
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(color: AppTheme.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.successGreen,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'OBD-II LOG',
                style: GoogleFonts.montserrat(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: log.isEmpty
                ? Center(
                    child: Text(
                      'Waiting for data...',
                      style: GoogleFonts.firaCode(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  )
                : ListView.builder(
                    reverse: true,
                    itemCount: log.length,
                    itemBuilder: (BuildContext context, int index) {
                      final int reverseIndex = log.length - 1 - index;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Text(
                          log[reverseIndex],
                          style: GoogleFonts.firaCode(
                            fontSize: 10,
                            color: AppTheme.successGreen
                                .withValues(alpha: 0.8),
                            height: 1.4,
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 500.ms, delay: 200.ms);
  }
}
