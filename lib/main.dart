import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'providers/dashboard_provider.dart';
import 'screens/home_shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock orientation to landscape only
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // Immersive full-screen: hide status bar and navigation bar
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  runApp(const CarDashboardApp());
}

/// Root application widget for the Car Dashboard.
class CarDashboardApp extends StatelessWidget {
  const CarDashboardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<DashboardProvider>(
      create: (_) => DashboardProvider(),
      child: MaterialApp(
        title: 'Car Dashboard',
        debugShowCheckedModeBanner: false,
        theme: _buildDarkTheme(),
        home: const HomeShell(),
      ),
    );
  }

  /// Constructs the strict dark theme with Montserrat typography
  /// and cyan accent colors.
  static ThemeData _buildDarkTheme() {
    const Color bgColor = Color(0xFF0A0A0A);
    const Color accentCyan = Color(0xFF00E5FF);
    const Color surfaceColor = Color(0xFF111111);

    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bgColor,
      canvasColor: surfaceColor,
      colorScheme: const ColorScheme.dark(
        primary: accentCyan,
        secondary: accentCyan,
        surface: surfaceColor,
      ),
      textTheme: GoogleFonts.montserratTextTheme(
        ThemeData.dark().textTheme,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: bgColor,
        elevation: 0,
      ),
      iconTheme: const IconThemeData(color: Colors.white70),
      useMaterial3: true,
    );
  }
}
