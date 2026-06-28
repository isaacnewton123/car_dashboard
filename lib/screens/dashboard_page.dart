import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
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
              final double gaugeSize = min(constraints.maxHeight * 0.60, constraints.maxWidth * 0.30);
              return Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Center Left: RPM Gauge
                      SizedBox(
                        width: gaugeSize,
                        height: gaugeSize,
                        child: _RpmGauge(rpm: p.rpm),
                      ).animate().fadeIn(duration: 800.ms, curve: Curves.easeOut),

                      // Center: Car Image
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40.0),
                        child: SizedBox(
                          width: constraints.maxWidth * 0.18,
                          child: Image.asset(
                            'assets/img/sigra.png',
                            fit: BoxFit.contain,
                          ).animate().fadeIn(duration: 800.ms, delay: 200.ms),
                        ),
                      ),

                      // Center Right: Speed Gauge
                      SizedBox(
                        width: gaugeSize,
                        height: gaugeSize,
                        child: _SpeedGauge(
                          speed: p.displaySpeed,
                          speedUnit: p.speedUnit.label,
                        ),
                      ).animate().fadeIn(duration: 800.ms, curve: Curves.easeOut),
                    ],
                  ),
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

class _RpmGauge extends StatelessWidget {
  const _RpmGauge({required this.rpm});
  
  final int rpm;

  @override
  Widget build(BuildContext context) {
    return SfRadialGauge(
      axes: <RadialAxis>[
        RadialAxis(
          minimum: 0,
          maximum: 8,
          startAngle: 140,
          endAngle: 40,
          showLabels: true,
          showTicks: true,
          tickOffset: 5,
          labelOffset: 15,
          axisLineStyle: const AxisLineStyle(
            thickness: 0.1,
            thicknessUnit: GaugeSizeUnit.factor,
            color: Color(0xFF1A1A1A), // Dark track
          ),
          majorTickStyle: const MajorTickStyle(length: 10, thickness: 2, color: Colors.grey),
          minorTickStyle: const MinorTickStyle(length: 5, thickness: 1, color: Colors.grey),
          axisLabelStyle: const GaugeTextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
          pointers: <GaugePointer>[
            RangePointer(
              value: rpm / 1000.0,
              width: 0.1,
              sizeUnit: GaugeSizeUnit.factor,
              gradient: const SweepGradient(
                colors: <Color>[AppTheme.accentCyan, AppTheme.accentBlue, AppTheme.alertRed],
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
                  Text(
                    (rpm / 1000.0).toStringAsFixed(1),
                    style: GoogleFonts.montserrat(
                      fontSize: 56,
                      fontWeight: FontWeight.w300,
                      color: Colors.white,
                      height: 1.0,
                      letterSpacing: -2,
                    ),
                  ),
                  Text(
                    'RPM x1000',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.accentCyan,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            )
          ],
        )
      ],
    );
  }
}

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
            color: Color(0xFF1A1A1A), // Dark track
          ),
          majorTickStyle: const MajorTickStyle(length: 10, thickness: 2, color: Colors.grey),
          minorTickStyle: const MinorTickStyle(length: 5, thickness: 1, color: Colors.grey),
          axisLabelStyle: const GaugeTextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
          pointers: <GaugePointer>[
            RangePointer(
              value: speed.toDouble(),
              width: 0.1,
              sizeUnit: GaugeSizeUnit.factor,
              gradient: const SweepGradient(
                colors: <Color>[AppTheme.successGreen, AppTheme.alertAmber, AppTheme.alertRed],
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
                  Text(
                    speed.toString(),
                    style: GoogleFonts.montserrat(
                      fontSize: 56,
                      fontWeight: FontWeight.w300,
                      color: Colors.white,
                      height: 1.0,
                      letterSpacing: -2,
                    ),
                  ),
                  Text(
                    speedUnit,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            )
          ],
        )
      ],
    );
  }
}
