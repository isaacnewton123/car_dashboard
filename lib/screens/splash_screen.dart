import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import 'home_shell.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _startBootSequence();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _startBootSequence() async {
    // Play the welcome sound as soon as the screen loads
    try {
      await _audioPlayer.play(AssetSource('sound/wellcome.mp3'));
    } catch (e) {
      debugPrint('Error playing sound: $e');
    }

    // Windows 11 first-run OOBE sequence (with initial delay for engine boot)
    await Future.delayed(const Duration(milliseconds: 11500));
    
    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 1500),
          pageBuilder: (context, animation, secondaryAnimation) =>
              const HomeShell(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // The font style for the Windows 11 OOBE
    final textStyle = GoogleFonts.openSans(
      fontSize: 32,
      fontWeight: FontWeight.w300, // Very light font weight for Windows 11 feel
      color: Colors.white,
    );

    return Scaffold(
      backgroundColor: Colors.black, // Windows 11 uses a deep black or very dark blue
      body: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Phase 1: Hi, Isaac Newton
            Text('Hi, Isaac Newton', style: textStyle)
                .animate(delay: 1500.ms) // Wait for Flutter engine to paint first frame
                .fadeIn(duration: 800.ms)
                .then(delay: 1200.ms)
                .fadeOut(duration: 800.ms),

            // Phase 2: Welcome
            Text('Welcome', style: textStyle)
                .animate(delay: 4500.ms)
                .fadeIn(duration: 800.ms)
                .then(delay: 1200.ms)
                .fadeOut(duration: 800.ms),

            // Phase 3: Drive carefully...
            Text('Drive carefully, and put on your seat belt', style: textStyle)
                .animate(delay: 7500.ms)
                .fadeIn(duration: 800.ms)
                .then(delay: 2000.ms)
                .fadeOut(duration: 800.ms),

            // Continuous Loading Indicator
            Positioned(
              bottom: 80,
              child: const SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
                ),
              )
                  .animate(delay: 500.ms)
                  .fadeIn(duration: 1000.ms)
                  .then(delay: 9000.ms) // stays visible for 9s
                  .fadeOut(duration: 1000.ms),
            ),
          ],
        ),
      ),
    );
  }
}
