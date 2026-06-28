import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:hugeicons/hugeicons.dart';

import '../models/dtc_code.dart';
import '../providers/dashboard_provider.dart';
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
              // Left: Vital Signs
              Expanded(
                flex: 5,
                child: Column(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Expanded(
                            child: _DiagnosticDataCard(
                              title: 'BATTERY VOLTAGE',
                              value: '${p.batteryVoltage.toStringAsFixed(1)} V',
                              subtitle: 'Control Module Voltage',
                              icon: HugeIcons.strokeRoundedBatteryFull,
                              valueColor: AppTheme.textPrimary,
                              delay: 100,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _DiagnosticDataCard(
                              title: 'ENGINE RUN TIME',
                              value: _formatDuration(ert),
                              subtitle: 'Time since ignition',
                              icon: HugeIcons.strokeRoundedTimer02,
                              valueColor: AppTheme.textPrimary,
                              delay: 200,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: _DiagnosticDataCard(
                        title: 'MIL STATUS',
                        value: milStatus ? 'ON (CHECK ENGINE)' : 'OFF (SYSTEM OK)',
                        subtitle: 'Malfunction Indicator Lamp',
                        icon: HugeIcons.strokeRoundedEngine,
                        valueColor: milStatus ? AppTheme.alertRed : AppTheme.successGreen,
                        delay: 300,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Right: DTCs and OBD Log
              Expanded(
                flex: 5,
                child: Column(
                  children: [
                    _ConnectionCard(isConnected: p.isConnected),
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
  const _ConnectionCard({required this.isConnected});
  final bool isConnected;

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
              color: isConnected
                  ? AppTheme.successGreen
                  : AppTheme.alertRed,
              boxShadow: [
                BoxShadow(
                  color: (isConnected
                          ? AppTheme.successGreen
                          : AppTheme.alertRed)
                      .withValues(alpha: 0.5),
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
                  isConnected ? 'Connected (Mock)' : 'Disconnected',
                  style: GoogleFonts.montserrat(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Text(
                  isConnected
                      ? 'ELM327 v2.1 • USB • 38400 baud'
                      : 'No OBD-II device detected',
                  style: GoogleFonts.montserrat(
                    fontSize: 10,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
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
