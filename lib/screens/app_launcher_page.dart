import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:installed_apps/app_info.dart';
import 'package:installed_apps/installed_apps.dart';

import '../theme/app_theme.dart';

/// Real app launcher page — grid of actual installed apps.
class AppLauncherPage extends StatefulWidget {
  const AppLauncherPage({super.key});

  @override
  State<AppLauncherPage> createState() => _AppLauncherPageState();
}

class _AppLauncherPageState extends State<AppLauncherPage> {
  List<AppInfo>? _apps;

  @override
  void initState() {
    super.initState();
    _loadApps();
  }

  Future<void> _loadApps() async {
    try {
      // excludeSystemApps = true, withIcon = true
      final apps = await InstalledApps.getInstalledApps(excludeSystemApps: true, withIcon: true);
      
      if (mounted) {
        setState(() {
          _apps = apps;
        });
      }
    } catch (e) {
      debugPrint('Failed to load apps: $e');
      if (mounted) {
        setState(() {
          _apps = [];
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_apps == null) {
      return const Center(
        child: CircularProgressIndicator(
          color: AppTheme.accentCyan,
        ),
      );
    }

    if (_apps!.isEmpty) {
      return Center(
        child: Text(
          'No apps found.',
          style: GoogleFonts.montserrat(
            fontSize: 18,
            color: AppTheme.textSecondary,
          ),
        ),
      );
    }

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          color: AppTheme.bgColor.withOpacity(0.65),
          child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 64.0, vertical: 64.0),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 8,
          mainAxisSpacing: 32,
          crossAxisSpacing: 32,
          childAspectRatio: 0.85,
        ),
        itemCount: _apps!.length,
        itemBuilder: (BuildContext context, int index) {
          final AppInfo app = _apps![index];
          return _AppTile(app: app, index: index);
        },
      ),
      ),
        ),
      ),
    );
  }
}

class _AppTile extends StatelessWidget {
  const _AppTile({required this.app, required this.index});

  final AppInfo app;
  final int index;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        InstalledApps.startApp(app.packageName);
      },
      child: Container(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: app.icon != null
                  ? Image.memory(
                      app.icon!,
                      fit: BoxFit.contain,
                    )
                  : const Icon(Icons.android_rounded, size: 40, color: AppTheme.accentCyan),
            ),
            const SizedBox(height: 8),
            Text(
              app.name,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.montserrat(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppTheme.textPrimary,
              ),
            ),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 400.ms, delay: (index * 20).ms)
        .scale(
          begin: const Offset(0.9, 0.9),
          end: const Offset(1.0, 1.0),
          duration: 400.ms,
          delay: (index * 20).ms,
        );
  }
}
