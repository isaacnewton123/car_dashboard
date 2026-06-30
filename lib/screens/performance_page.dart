import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';

import '../providers/dashboard_provider.dart';
import '../theme/app_theme.dart';

/// Engine Performance Page — Technical data using Syncfusion gauges.
class PerformancePage extends StatelessWidget {
  const PerformancePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<DashboardProvider>(
      builder: (BuildContext context, DashboardProvider p, _) {
        return Padding(
          padding: const EdgeInsets.all(AppTheme.pagePadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Text(
                  'ENGINE PERFORMANCE',
                  style: GoogleFonts.montserrat(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                    letterSpacing: 4,
                  ),
                ).animate().fadeIn(duration: 400.ms),
              ),
              const SizedBox(height: 4),
              Center(
                child: Text(
                  '1,200cc Engine Telemetry',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ).animate().fadeIn(duration: 400.ms, delay: 100.ms),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: Row(
                  children: [
                    // Column 1: Engine Load + Throttle
                    Expanded(
                      child: Column(
                        children: [
                          Expanded(
                            child: _RadialPerformanceGauge(
                              title: 'ENGINE LOAD',
                              value: p.engineLoad.toDouble(),
                              minValue: 0,
                              maxValue: 100,
                              unit: '%',
                              startColor: AppTheme.accentCyan,
                              endColor: Colors.blueAccent,
                              delay: 200,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Expanded(
                            child: _RadialPerformanceGauge(
                              title: 'THROTTLE',
                              value: p.throttlePosition.toDouble(),
                              minValue: 0,
                              maxValue: 100,
                              unit: '%',
                              startColor: AppTheme.successGreen,
                              endColor: Colors.tealAccent,
                              delay: 300,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Column 2: Intake Temp + MAP/Barometric
                    Expanded(
                      child: Column(
                        children: [
                          Expanded(
                            child: _RadialPerformanceGauge(
                              title: 'INTAKE TEMP',
                              value: p.intakeAirTemp.toDouble(),
                              minValue: 0,
                              maxValue: 100,
                              unit: '°C',
                              startColor: Colors.orange,
                              endColor: Colors.yellowAccent,
                              delay: 400,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Expanded(
                            child: _RadialPerformanceGauge(
                              title: 'BAROMETRIC',
                              value: p.barometricPressure.toDouble(),
                              minValue: 70,
                              maxValue: 110,
                              unit: 'kPa',
                              startColor: AppTheme.alertAmber,
                              endColor: AppTheme.alertRed,
                              delay: 500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Column 3: Ignition Timing + Abs Engine Load
                    Expanded(
                      child: Column(
                        children: [
                          Expanded(
                            child: _RadialPerformanceGauge(
                              title: 'IGN TIMING',
                              value: p.ignitionTiming,
                              minValue: -20,
                              maxValue: 40,
                              unit: '°',
                              startColor: Colors.purpleAccent,
                              endColor: Colors.pinkAccent,
                              delay: 600,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Expanded(
                            child: _RadialPerformanceGauge(
                              title: 'ABS LOAD',
                              value: p.absoluteEngineLoad.clamp(0, 100),
                              minValue: 0,
                              maxValue: 100,
                              unit: '%',
                              startColor: Colors.deepOrangeAccent,
                              endColor: Colors.redAccent,
                              delay: 700,
                            ),
                          ),
                        ],
                      ),
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
}

class _RadialPerformanceGauge extends StatelessWidget {
  const _RadialPerformanceGauge({
    required this.title,
    required this.value,
    required this.minValue,
    required this.maxValue,
    required this.unit,
    required this.startColor,
    required this.endColor,
    required this.delay,
  });

  final String title;
  final double value;
  final double minValue;
  final double maxValue;
  final String unit;
  final Color startColor;
  final Color endColor;
  final int delay;

  Widget build(BuildContext context) {
    return Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              title,
              style: GoogleFonts.montserrat(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
                letterSpacing: 2,
              ),
            ),
          ),
          Expanded(
            child: SfRadialGauge(
              axes: <RadialAxis>[
                RadialAxis(
                  minimum: minValue,
                  maximum: maxValue,
                  startAngle: 140,
                  endAngle: 40,
                  showLabels: true,
                  showTicks: true,
                  tickOffset: 5,
                  labelOffset: 15,
                  axisLineStyle: const AxisLineStyle(
                    thickness: 0.25,
                    thicknessUnit: GaugeSizeUnit.factor,
                    color: Color(0xFF1A1A1A), // Dark track
                  ),
                  majorTickStyle: const MajorTickStyle(
                    length: 8,
                    thickness: 3,
                    color: Colors.grey,
                  ),
                  minorTickStyle: const MinorTickStyle(
                    length: 4,
                    thickness: 1,
                    color: Colors.grey,
                  ),
                  axisLabelStyle: const GaugeTextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                  pointers: <GaugePointer>[
                    RangePointer(
                      value: value,
                      width: 0.25,
                      sizeUnit: GaugeSizeUnit.factor,
                      gradient: SweepGradient(
                        colors: <Color>[startColor, endColor],
                        stops: const <double>[0.0, 1.0],
                      ),
                      cornerStyle: CornerStyle.bothCurve,
                      animationDuration: 1000,
                      enableAnimation: true,
                    ),
                  ],
                  annotations: <GaugeAnnotation>[
                    GaugeAnnotation(
                      positionFactor: 0.05,
                      angle: 90,
                      widget: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TweenAnimationBuilder<double>(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOutCubic,
                            tween: Tween<double>(begin: 0, end: value),
                            builder: (context, val, _) => Text(
                              val.toInt().toString(),
                              style: GoogleFonts.montserrat(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.textPrimary,
                                letterSpacing: -1,
                              ),
                            ),
                          ),
                          Text(
                            unit,
                            style: GoogleFonts.montserrat(
                              fontSize: 14,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ).animate().fadeIn(duration: 500.ms, delay: delay.ms);
  }
}
