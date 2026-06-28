import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';

import '../theme/app_theme.dart';

class MediaPage extends StatefulWidget {
  const MediaPage({super.key});

  @override
  State<MediaPage> createState() => _MediaPageState();
}

class _MediaPageState extends State<MediaPage> {
  bool _isPlaying = false;
  bool _isShuffle = false;
  bool _isRepeat = false;
  double _progress = 0.35;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Background blurred image / gradient
        Positioned.fill(
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF1A237E),
                  Color(0xFF006064),
                ],
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
            child: Container(color: Colors.black.withValues(alpha: 0.4)),
          ),
        ),
        
        // Content
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48.0, vertical: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Album Art (Spotify Style)
                Expanded(
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFF1A237E),
                              Color(0xFF0D47A1),
                              Color(0xFF006064),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.5),
                              blurRadius: 40,
                              offset: const Offset(0, 20),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: HugeIcon(
                            icon: HugeIcons.strokeRoundedMusicNote01,
                            size: 80,
                            color: Colors.white54,
                          ),
                        ),
                      ).animate(target: _isPlaying ? 1 : 0).scale(
                        begin: const Offset(0.95, 0.95),
                        end: const Offset(1.0, 1.0),
                        duration: 300.ms,
                        curve: Curves.easeOutBack,
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // Track Info & Heart
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Midnight Drive',
                          style: GoogleFonts.montserrat(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Synthwave FM',
                          style: GoogleFonts.montserrat(
                            fontSize: 18,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(
                        Icons.favorite_border_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 24),
                
                // Progress bar
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: Colors.white,
                    inactiveTrackColor: Colors.white24,
                    thumbColor: Colors.white,
                    trackHeight: 4,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                  ),
                  child: Slider(
                    value: _progress,
                    onChanged: (double v) => setState(() => _progress = v),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatTime((_progress * 245).round()),
                        style: GoogleFonts.montserrat(
                            fontSize: 12, color: Colors.white54, fontWeight: FontWeight.w500),
                      ),
                      Text(
                        '4:05',
                        style: GoogleFonts.montserrat(
                            fontSize: 12, color: Colors.white54, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Controls
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      onPressed: () => setState(() => _isShuffle = !_isShuffle),
                      icon: Icon(
                        Icons.shuffle_rounded,
                        color: _isShuffle ? AppTheme.accentCyan : Colors.white54,
                        size: 28,
                      ),
                    ),
                    IconButton(
                      onPressed: () {},
                      icon: const HugeIcon(
                        icon: HugeIcons.strokeRoundedPrevious,
                        color: Colors.white,
                        size: 40,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => setState(() => _isPlaying = !_isPlaying),
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Center(
                          child: HugeIcon(
                            icon: _isPlaying
                                ? HugeIcons.strokeRoundedPause
                                : HugeIcons.strokeRoundedPlay,
                            color: Colors.black,
                            size: 36,
                          ),
                        ),
                      ).animate(target: _isPlaying ? 1 : 0).scale(
                        begin: const Offset(1.0, 1.0),
                        end: const Offset(1.05, 1.05),
                        duration: 200.ms,
                      ),
                    ),
                    IconButton(
                      onPressed: () {},
                      icon: const HugeIcon(
                        icon: HugeIcons.strokeRoundedNext,
                        color: Colors.white,
                        size: 40,
                      ),
                    ),
                    IconButton(
                      onPressed: () => setState(() => _isRepeat = !_isRepeat),
                      icon: Icon(
                        Icons.repeat_rounded,
                        color: _isRepeat ? AppTheme.accentCyan : Colors.white54,
                        size: 28,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _formatTime(int totalSeconds) {
    final int minutes = totalSeconds ~/ 60;
    final int seconds = totalSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}
