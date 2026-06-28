import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:hugeicons/hugeicons.dart';

import '../providers/dashboard_provider.dart';
import '../theme/app_theme.dart';

/// Full-page AI Assistant with mic button, conversation history,
/// and model badge.
class AssistantPage extends StatelessWidget {
  const AssistantPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<DashboardProvider>(
      builder: (BuildContext context, DashboardProvider p, _) {
        return Padding(
          padding: const EdgeInsets.all(AppTheme.pagePadding),
          child: Row(
            children: [
              // Left: Mic + Status
              Expanded(
                flex: 4,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Model badge
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: AppTheme.accentCyan.withValues(alpha: 0.4),
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              HugeIcon(
                                icon: HugeIcons.strokeRoundedCpu,
                                color: AppTheme.accentCyan,
                                size: 14,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                p.selectedModel.displayName,
                                style: GoogleFonts.montserrat(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.accentCyan,
                                  letterSpacing: 1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 48),
                    // Mic button
                    _MicButton(
                      isListening: p.isListening,
                      isProcessing: p.isProcessing,
                      onPressed: () {
                        if (p.isListening) {
                          p.stopListening();
                        } else {
                          p.startListening();
                        }
                      },
                    ),
                    const SizedBox(height: 32),
                    Text(
                      p.isListening
                          ? 'Listening...'
                          : p.isProcessing
                              ? 'Thinking...'
                              : 'Tap to speak',
                      style: GoogleFonts.montserrat(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: p.isListening || p.isProcessing
                            ? AppTheme.accentCyan
                            : AppTheme.textSecondary,
                        letterSpacing: 1,
                      ),
                    ).animate(target: p.isListening ? 1 : 0).fade(),
                  ],
                ),
              ),
              // Right: Conversation
              Expanded(
                flex: 6,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppTheme.glassFill,
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusCard),
                        border: Border.all(color: AppTheme.glassBorder),
                      ),
                      child: _ConversationArea(
                        transcription: p.transcription,
                        aiResponse: p.aiResponse,
                        isProcessing: p.isProcessing,
                      ),
                    ),
                  ),
                ).animate().fadeIn(duration: 500.ms).slideX(begin: 0.05),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Mic Button
// ---------------------------------------------------------------------------

class _MicButton extends StatelessWidget {
  const _MicButton({
    required this.isListening,
    required this.isProcessing,
    required this.onPressed,
  });

  final bool isListening;
  final bool isProcessing;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final Color color =
        isProcessing ? AppTheme.alertRed : AppTheme.accentCyan;

    return GestureDetector(
      onTap: isProcessing ? null : onPressed,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background pulsing glow when listening
          if (isListening)
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.2),
              ),
            )
                .animate(onPlay: (controller) => controller.repeat(reverse: true))
                .scale(begin: const Offset(0.8, 0.8), end: const Offset(1.2, 1.2), duration: 1000.ms)
                .fade(begin: 0.5, end: 0.0, duration: 1000.ms),
          
          // Outer ripple
          if (isListening)
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.3),
              ),
            )
                .animate(onPlay: (controller) => controller.repeat(reverse: true))
                .scale(begin: const Offset(0.9, 0.9), end: const Offset(1.1, 1.1), duration: 800.ms),

          // Main Button
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isListening
                  ? color.withValues(alpha: 0.3)
                  : AppTheme.surfaceColor,
              border: Border.all(color: color, width: 2),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: isListening ? 0.6 : 0.2),
                  blurRadius: isListening ? 30 : 12,
                  spreadRadius: isListening ? 4 : 0,
                ),
              ],
            ),
            child: HugeIcon(
              icon: HugeIcons.strokeRoundedMic01,
              color: color,
              size: 36,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Conversation Area
// ---------------------------------------------------------------------------

class _ConversationArea extends StatelessWidget {
  const _ConversationArea({
    required this.transcription,
    required this.aiResponse,
    required this.isProcessing,
  });

  final String transcription;
  final String aiResponse;
  final bool isProcessing;

  @override
  Widget build(BuildContext context) {
    if (transcription.isEmpty && aiResponse.isEmpty && !isProcessing) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            HugeIcon(
              icon: HugeIcons.strokeRoundedVoice,
              size: 48,
              color: AppTheme.textSecondary.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'Tap the mic to ask\nyour AI assistant',
              textAlign: TextAlign.center,
              style: GoogleFonts.montserrat(
                fontSize: 14,
                color: AppTheme.textSecondary.withValues(alpha: 0.5),
                height: 1.5,
              ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      reverse: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (transcription.isNotEmpty)
            _ChatBubble(
              text: transcription,
              isUser: true,
            ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1),
          
          const SizedBox(height: 16),
          
          if (isProcessing)
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 12.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List<Widget>.generate(
                    3,
                    (int i) => Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.accentCyan.withValues(alpha: 0.7),
                        shape: BoxShape.circle,
                      ),
                    )
                        .animate(onPlay: (c) => c.repeat())
                        .slideY(
                          begin: 0,
                          end: -0.5,
                          duration: 300.ms,
                          delay: (i * 100).ms,
                          curve: Curves.easeInOut,
                        )
                        .then()
                        .slideY(
                          begin: -0.5,
                          end: 0,
                          duration: 300.ms,
                          curve: Curves.easeInOut,
                        ),
                  ),
                ),
              ),
            )
          else if (aiResponse.isNotEmpty)
            _ChatBubble(
              text: aiResponse,
              isUser: false,
            ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Chat Bubble Widget
// ---------------------------------------------------------------------------

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({
    required this.text,
    required this.isUser,
  });

  final String text;
  final bool isUser;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (!isUser) ...[
          CircleAvatar(
            backgroundColor: AppTheme.accentCyan.withValues(alpha: 0.1),
            radius: 16,
            child: HugeIcon(
              icon: HugeIcons.strokeRoundedCpu,
              color: AppTheme.accentCyan,
              size: 18,
            ),
          ),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(
              color: isUser ? AppTheme.accentCyan : Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(20),
                topRight: const Radius.circular(20),
                bottomLeft: Radius.circular(isUser ? 20 : 4),
                bottomRight: Radius.circular(isUser ? 4 : 20),
              ),
              border: isUser
                  ? null
                  : Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                      width: 1,
                    ),
            ),
            child: Text(
              text,
              style: GoogleFonts.montserrat(
                fontSize: 14,
                color: isUser ? Colors.black87 : AppTheme.textPrimary,
                height: 1.5,
                fontWeight: isUser ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ),
        ),
        if (isUser) ...[
          const SizedBox(width: 8),
          CircleAvatar(
            backgroundColor: AppTheme.surfaceLight,
            radius: 16,
            child: HugeIcon(
              icon: HugeIcons.strokeRoundedUser,
              color: AppTheme.textSecondary,
              size: 18,
            ),
          ),
        ],
      ],
    );
  }
}
