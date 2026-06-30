import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../providers/dashboard_provider.dart';
import '../theme/app_theme.dart';

/// Fuel Efficiency Page
class TripPage extends StatelessWidget {
  const TripPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<DashboardProvider>(
      builder: (BuildContext context, DashboardProvider p, _) {
        return Padding(
          padding: const EdgeInsets.all(AppTheme.pagePadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Center(
                child: Text(
                  'FUEL EFFICIENCY',
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
                  'Injection & Driving Style Monitor',
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
                    // Column 1: Fuel Rate + O2 Sensor
                    Expanded(
                      child: Column(
                        children: [
                          Expanded(
                            child: _DigitalDataCard(
                              title: 'FUEL ECONOMY',
                              value: p.fuelEconomy,
                              unit: 'km/L',
                              delay: 200,
                              icon: HugeIcons.strokeRoundedDroplet,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Expanded(
                            child: _DigitalDataCard(
                              title: 'O2 SENSOR',
                              value: p.o2SensorVoltage,
                              unit: 'V',
                              delay: 300,
                              fractionDigits: 2,
                              icon: HugeIcons.strokeRoundedFlash,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Column 2: Short FT + Trip Meter
                    Expanded(
                      child: Column(
                        children: [
                          Expanded(
                            child: _DigitalDataCard(
                              title: 'SHORT FT',
                              value: p.shortTermFuelTrim,
                              unit: '%',
                              delay: 400,
                              fractionDigits: 1,
                              icon: HugeIcons.strokeRoundedSettings01,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Expanded(
                            child: _DigitalDataCard(
                              title: 'TRIP METER',
                              value: p.tripDistance,
                              unit: 'km',
                              delay: 500,
                              icon: HugeIcons.strokeRoundedCar01,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Column 3: MAF + Lambda/Equiv Ratio
                    Expanded(
                      child: Column(
                        children: [
                          Expanded(
                            child: _DigitalDataCard(
                              title: 'MAF FLOW',
                              value: p.mafAirFlow,
                              unit: 'g/s',
                              delay: 600,
                              fractionDigits: 1,
                              icon: HugeIcons.strokeRoundedDashboardSpeed02,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Expanded(
                            child: _DigitalDataCard(
                              title: 'LONG FT',
                              value: p.longTermFuelTrim,
                              unit: '%',
                              delay: 700,
                              fractionDigits: 1,
                              icon: HugeIcons.strokeRoundedAnalytics01,
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

class _DigitalDataCard extends StatelessWidget {
  const _DigitalDataCard({
    required this.title,
    required this.value,
    required this.unit,
    required this.delay,
    required this.icon,
    this.fractionDigits = 1,
  });

  final String title;
  final double value;
  final String unit;
  final int delay;
  final int fractionDigits;
  final dynamic icon;

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
            border: Border.all(color: Colors.white.withOpacity(0.08), width: 1),
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
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  TweenAnimationBuilder<double>(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    tween: Tween<double>(begin: 0, end: value),
                    builder: (context, val, _) => Text(
                      val.toStringAsFixed(fractionDigits),
                      style: GoogleFonts.montserrat(
                        fontSize: 56,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                        letterSpacing: -1.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Text(
                      unit,
                      style: GoogleFonts.montserrat(
                        fontSize: 14,
                        color: AppTheme.accentCyan,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
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
