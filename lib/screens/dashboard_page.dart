import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';

import '../providers/dashboard_provider.dart';
import '../theme/app_theme.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<DashboardProvider>(
      builder: (BuildContext context, DashboardProvider p, _) {
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                color: const Color(0xFF27282A).withValues(alpha: 0.5),
                child: LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    final double gaugeSize = min(
                      constraints.maxHeight * 0.55,
                      constraints.maxWidth * 0.25,
                    );
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32.0,
                        vertical: 16.0,
                      ),
                      child: Column(
                        children: [
                          // ── Top Row: Gauges + Car ──
                          Expanded(
                            flex: 6,
                            child: Row(
                              children: [
                                // Left info cards
                                Expanded(
                                  flex: 2,
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      _InfoCard(
                                        hugeIcon: HugeIcons.strokeRoundedThermometer,
                                        label: 'COOLANT',
                                        value: '${p.coolantTemp}°C',
                                        valueColor: p.coolantTemp > 95
                                            ? AppTheme.alertRed
                                            : p.coolantTemp > 85
                                                ? AppTheme.alertAmber
                                                : AppTheme.accentCyan,
                                      ).animate().fadeIn(duration: 600.ms, delay: 100.ms),
                                      const SizedBox(height: 12),
                                      _InfoCard(
                                        materialIcon: Icons.bolt_rounded,
                                        label: 'TIMING',
                                        value: '${p.ignitionTiming.toStringAsFixed(1)}°',
                                        valueColor: AppTheme.successGreen,
                                      ).animate().fadeIn(duration: 600.ms, delay: 200.ms),
                                      const SizedBox(height: 12),
                                      _InfoCard(
                                        hugeIcon: HugeIcons.strokeRoundedBatteryFull,
                                        label: 'BATTERY',
                                        value: '${p.batteryVoltage.toStringAsFixed(1)}V',
                                        valueColor: p.batteryVoltage < 12.0
                                            ? AppTheme.alertRed
                                            : AppTheme.accentCyan,
                                      ).animate().fadeIn(duration: 600.ms, delay: 300.ms),
                                    ],
                                  ),
                                ),

                                // RPM Gauge
                                SizedBox(
                                  width: gaugeSize,
                                  height: gaugeSize,
                                  child: _RpmGauge(rpm: p.rpm),
                                ).animate().fadeIn(duration: 800.ms, curve: Curves.easeOut),

                                // Center: Car + Gear
                                Expanded(
                                  flex: 2,
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      // OBD-II Connection Status
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                            color: p.isConnected
                                                ? AppTheme.successGreen.withValues(alpha: 0.3)
                                                : AppTheme.alertRed.withValues(alpha: 0.3),
                                          ),
                                          borderRadius: BorderRadius.circular(12),
                                          color: AppTheme.glassFill,
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Container(
                                              width: 8,
                                              height: 8,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: p.isConnected
                                                    ? AppTheme.successGreen
                                                    : AppTheme.alertRed,
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: (p.isConnected
                                                            ? AppTheme.successGreen
                                                            : AppTheme.alertRed)
                                                        .withValues(alpha: 0.5),
                                                    blurRadius: 6,
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              p.isConnected ? 'OBD-II LINKED' : 'DISCONNECTED',
                                              style: GoogleFonts.inter(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                                color: p.isConnected
                                                    ? AppTheme.successGreen
                                                    : AppTheme.alertRed,
                                                letterSpacing: 1.5,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ).animate().fadeIn(duration: 600.ms, delay: 200.ms),
                                      const SizedBox(height: 12),
                                      // Car image
                                      SizedBox(
                                        width: constraints.maxWidth * 0.15,
                                        child: Image.asset(
                                          'assets/img/sigra.png',
                                          fit: BoxFit.contain,
                                        ).animate().fadeIn(duration: 800.ms, delay: 200.ms),
                                      ),
                                      const SizedBox(height: 8),
                                      // Engine load bar
                                      SizedBox(
                                        width: constraints.maxWidth * 0.12,
                                        child: Column(
                                          children: [
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.spaceBetween,
                                              children: [
                                                Text(
                                                  'ENGINE LOAD',
                                                  style: GoogleFonts.inter(
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.w600,
                                                    color: AppTheme.textSecondary,
                                                    letterSpacing: 1.5,
                                                  ),
                                                ),
                                                Text(
                                                  '${p.engineLoad}%',
                                                  style: GoogleFonts.montserrat(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w700,
                                                    color: AppTheme.textPrimary,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            ClipRRect(
                                              borderRadius: BorderRadius.circular(4),
                                              child: TweenAnimationBuilder<double>(
                                                duration: const Duration(milliseconds: 300),
                                                curve: Curves.easeOutCubic,
                                                tween: Tween<double>(begin: 0, end: p.engineLoad / 100.0),
                                                builder: (context, value, _) => LinearProgressIndicator(
                                                  value: value,
                                                  minHeight: 5,
                                                  backgroundColor:
                                                      AppTheme.surfaceLight,
                                                  valueColor:
                                                      AlwaysStoppedAnimation<Color>(
                                                    p.engineLoad > 80
                                                        ? AppTheme.alertRed
                                                        : p.engineLoad > 50
                                                            ? AppTheme.alertAmber
                                                            : AppTheme.accentCyan,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ).animate().fadeIn(duration: 600.ms, delay: 400.ms),
                                    ],
                                  ),
                                ),

                                // Speed Gauge
                                SizedBox(
                                  width: gaugeSize,
                                  height: gaugeSize,
                                  child: _SpeedGauge(
                                    speed: p.displaySpeed,
                                    speedUnit: p.speedUnit.label,
                                  ),
                                ).animate().fadeIn(duration: 800.ms, curve: Curves.easeOut),

                                // Right info cards
                                Expanded(
                                  flex: 2,
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      _InfoCard(
                                        materialIcon: Icons.speed_rounded,
                                        label: 'THROTTLE',
                                        value: '${p.throttlePosition}%',
                                        valueColor: AppTheme.accentCyan,
                                      ).animate().fadeIn(duration: 600.ms, delay: 100.ms),
                                      const SizedBox(height: 12),
                                      _InfoCard(
                                        materialIcon: Icons.air_rounded,
                                        label: 'INTAKE AIR',
                                        value: '${p.intakeAirTemp}°C',
                                        valueColor: AppTheme.accentCyan,
                                      ).animate().fadeIn(duration: 600.ms, delay: 200.ms),
                                      const SizedBox(height: 12),
                                      _InfoCard(
                                        materialIcon: Icons.compress_rounded,
                                        label: 'BARO',
                                        value: '${p.barometricPressure} kPa',
                                        valueColor: AppTheme.accentCyan,
                                      ).animate().fadeIn(duration: 600.ms, delay: 300.ms),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // ── Bottom: Quote + Quick Stats ──
                          Expanded(
                            flex: 2,
                            child: Row(
                              children: [
                                // Quote card
                                Expanded(
                                  flex: 3,
                                  child: _QuoteCard().animate().fadeIn(
                                        duration: 800.ms,
                                        delay: 500.ms,
                                      ),
                                ),
                                const SizedBox(width: 16),
                                // Fuel rate
                                Expanded(
                                  flex: 2,
                                  child: _StatTile(
                                    icon: HugeIcons.strokeRoundedFlash,
                                    label: 'FUEL RATE',
                                    value: '${p.fuelRate.toStringAsFixed(1)} L/h',
                                    accent: AppTheme.alertAmber,
                                  ).animate().fadeIn(duration: 600.ms, delay: 500.ms),
                                ),
                                const SizedBox(width: 16),
                                // O2 Sensor
                                Expanded(
                                  flex: 2,
                                  child: _StatTile(
                                    icon: HugeIcons.strokeRoundedFlash,
                                    label: 'O₂ SENSOR',
                                    value:
                                        '${p.o2SensorVoltage.toStringAsFixed(2)}V',
                                    accent: AppTheme.successGreen,
                                  ).animate().fadeIn(duration: 600.ms, delay: 600.ms),
                                ),
                                const SizedBox(width: 16),
                                // Fuel Trim
                                Expanded(
                                  flex: 2,
                                  child: _StatTile(
                                    icon: HugeIcons.strokeRoundedSettings01,
                                    label: 'FUEL TRIM',
                                    value:
                                        '${p.fuelTrim >= 0 ? '+' : ''}${p.fuelTrim.toStringAsFixed(1)}%',
                                    accent: p.fuelTrim.abs() > 10
                                        ? AppTheme.alertRed
                                        : AppTheme.accentCyan,
                                  ).animate().fadeIn(duration: 600.ms, delay: 700.ms),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// =============================================================================
// Quote Card
// =============================================================================

class _QuoteCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.glassFill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.glassBorder),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.format_quote_rounded,
            color: AppTheme.accentCyan.withValues(alpha: 0.4),
            size: 18,
          ),
          const SizedBox(height: 4),
          Flexible(
            child: Text(
              '"What we know is just a drop in the ocean; what we don\'t know is an ocean."',
              style: GoogleFonts.playfairDisplay(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                fontStyle: FontStyle.italic,
                color: AppTheme.textPrimary.withValues(alpha: 0.85),
                height: 1.4,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '— Sir Isaac Newton',
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppTheme.accentCyan,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Info Card — Small glassmorphic card for side panels
// =============================================================================

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    this.hugeIcon,
    this.materialIcon,
    required this.label,
    required this.value,
    required this.valueColor,
  }) : assert(hugeIcon != null || materialIcon != null);

  final List<List<dynamic>>? hugeIcon;
  final IconData? materialIcon;
  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120, // fixed width to keep them even and short
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.glassFill,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.glassBorder),
      ),
      child: Row(
        children: [
          hugeIcon != null
              ? HugeIcon(icon: hugeIcon!, color: AppTheme.textSecondary, size: 16)
              : Icon(materialIcon!, color: AppTheme.textSecondary, size: 16),
          const Spacer(),
          Text(
            value,
            style: GoogleFonts.montserrat(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Stat Tile — Bottom bar stat cards
// =============================================================================

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
  });

  final List<List<dynamic>> icon;
  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.glassFill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.glassBorder),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          HugeIcon(icon: icon, color: accent, size: 22),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.montserrat(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// RPM Gauge
// =============================================================================

class _RpmGauge extends StatelessWidget {
  const _RpmGauge({required this.rpm});

  final int rpm;

  @override
  Widget build(BuildContext context) {
    return SfRadialGauge(
      axes: <RadialAxis>[
        RadialAxis(
          minimum: 0,
          maximum: 8000,
          interval: 1000,
          startAngle: 140,
          endAngle: 40,
          showLabels: true,
          showTicks: true,
          tickOffset: 5,
          labelOffset: 15,
          axisLineStyle: const AxisLineStyle(
            thickness: 0.1,
            thicknessUnit: GaugeSizeUnit.factor,
            color: Color(0xFF1A1A1A),
          ),
          majorTickStyle: const MajorTickStyle(
            length: 10,
            thickness: 2,
            color: Colors.grey,
          ),
          minorTickStyle: const MinorTickStyle(
            length: 5,
            thickness: 1,
            color: Colors.grey,
          ),
          axisLabelStyle: const GaugeTextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
          pointers: <GaugePointer>[
            RangePointer(
              value: rpm.toDouble(),
              enableAnimation: true,
              animationDuration: 300,
              width: 0.1,
              sizeUnit: GaugeSizeUnit.factor,
              gradient: const SweepGradient(
                colors: <Color>[
                  AppTheme.accentCyan,
                  AppTheme.accentBlue,
                  AppTheme.alertRed,
                ],
                stops: <double>[0.0, 0.7, 1.0],
              ),
              cornerStyle: CornerStyle.bothCurve,
            ),
          ],
          annotations: <GaugeAnnotation>[
            GaugeAnnotation(
              positionFactor: 0.1,
              angle: 90,
              widget: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TweenAnimationBuilder<double>(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    tween: Tween<double>(begin: 0, end: rpm.toDouble()),
                    builder: (context, val, _) => Text(
                      val.toInt().toString(),
                      style: GoogleFonts.montserrat(
                        fontSize: 48,
                        fontWeight: FontWeight.w300,
                        color: Colors.white,
                        height: 1.0,
                        letterSpacing: -2,
                      ),
                    ),
                  ),
                  Text(
                    'RPM',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.accentCyan,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// =============================================================================
// Speed Gauge
// =============================================================================

class _SpeedGauge extends StatelessWidget {
  const _SpeedGauge({
    required this.speed,
    required this.speedUnit,
  });

  final int speed;
  final String speedUnit;

  @override
  Widget build(BuildContext context) {
    return SfRadialGauge(
      axes: <RadialAxis>[
        RadialAxis(
          minimum: 0,
          maximum: 200,
          startAngle: 140,
          endAngle: 40,
          showLabels: true,
          showTicks: true,
          tickOffset: 5,
          labelOffset: 15,
          axisLineStyle: const AxisLineStyle(
            thickness: 0.1,
            thicknessUnit: GaugeSizeUnit.factor,
            color: Color(0xFF1A1A1A),
          ),
          majorTickStyle: const MajorTickStyle(
            length: 10,
            thickness: 2,
            color: Colors.grey,
          ),
          minorTickStyle: const MinorTickStyle(
            length: 5,
            thickness: 1,
            color: Colors.grey,
          ),
          axisLabelStyle: const GaugeTextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
          pointers: <GaugePointer>[
            RangePointer(
              value: speed.toDouble(),
              enableAnimation: true,
              animationDuration: 300,
              width: 0.1,
              sizeUnit: GaugeSizeUnit.factor,
              gradient: const SweepGradient(
                colors: <Color>[
                  AppTheme.successGreen,
                  AppTheme.alertAmber,
                  AppTheme.alertRed,
                ],
                stops: <double>[0.0, 0.6, 1.0],
              ),
              cornerStyle: CornerStyle.bothCurve,
            ),
          ],
          annotations: <GaugeAnnotation>[
            GaugeAnnotation(
              positionFactor: 0.1,
              angle: 90,
              widget: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TweenAnimationBuilder<double>(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    tween: Tween<double>(begin: 0, end: speed.toDouble()),
                    builder: (context, val, _) => Text(
                      val.toInt().toString(),
                      style: GoogleFonts.montserrat(
                        fontSize: 48,
                        fontWeight: FontWeight.w300,
                        color: Colors.white,
                        height: 1.0,
                        letterSpacing: -2,
                      ),
                    ),
                  ),
                  Text(
                    speedUnit,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
