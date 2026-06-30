import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_classic_bluetooth/flutter_classic_bluetooth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../models/gemini_model.dart';
import '../providers/dashboard_provider.dart';
import '../services/obd_connection_state.dart';
import '../theme/app_theme.dart';

/// Full-page settings — API key, model selector, units, about.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<DashboardProvider>(
      builder: (BuildContext context, DashboardProvider p, _) {
        return Padding(
          padding: const EdgeInsets.all(AppTheme.pagePadding),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left: API Key + Units
              Expanded(
                flex: 5,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // API Key section
                      _SectionHeader(title: 'GEMINI API KEY'),
                      const SizedBox(height: 10),
                      _ApiKeyField(currentKey: p.apiKey, provider: p),
                      const SizedBox(height: 24),

                      // Speed unit
                      _SectionHeader(title: 'SPEED UNIT'),
                      const SizedBox(height: 10),
                      _UnitToggle(
                        currentUnit: p.speedUnit,
                        onChanged: p.saveSpeedUnit,
                      ),
                      const SizedBox(height: 24),

                      _SectionHeader(title: 'ABOUT'),
                      const SizedBox(height: 10),
                      _AboutCard(),
                      const SizedBox(height: 24),

                      // OBD-II Connection
                      _SectionHeader(title: 'OBD-II CONNECTION'),
                      const SizedBox(height: 10),
                      _ObdConnectionCard(provider: p),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 20),
              // Right: Model selector
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionHeader(title: 'GEMINI MODEL'),
                    const SizedBox(height: 10),
                    Expanded(
                      child: _ModelSelector(
                        selectedModel: p.selectedModel,
                        onSelected: p.saveSelectedModel,
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

// ---------------------------------------------------------------------------
// Section Header
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: GoogleFonts.montserrat(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        color: AppTheme.textSecondary,
        letterSpacing: 3,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// API Key Field
// ---------------------------------------------------------------------------

class _ApiKeyField extends StatefulWidget {
  const _ApiKeyField({required this.currentKey, required this.provider});
  final String currentKey;
  final DashboardProvider provider;

  @override
  State<_ApiKeyField> createState() => _ApiKeyFieldState();
}

class _ApiKeyFieldState extends State<_ApiKeyField> {
  late final TextEditingController _controller;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentKey);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            obscureText: true,
            style: GoogleFonts.montserrat(
              fontSize: 13,
              color: AppTheme.textPrimary,
            ),
            decoration: InputDecoration(
              hintText: 'Paste your API key...',
              hintStyle: GoogleFonts.montserrat(
                fontSize: 13,
                color: AppTheme.textSecondary.withValues(alpha: 0.4),
              ),
              filled: true,
              fillColor: AppTheme.surfaceColor,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(AppTheme.radiusSmall),
                borderSide: BorderSide(color: AppTheme.glassBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(AppTheme.radiusSmall),
                borderSide: BorderSide(color: AppTheme.glassBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(AppTheme.radiusSmall),
                borderSide:
                    const BorderSide(color: AppTheme.accentCyan),
              ),
              prefixIcon: const Icon(Icons.key_rounded,
                  color: AppTheme.textSecondary, size: 18),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          height: 46,
          child: ElevatedButton(
            onPressed: () {
              widget.provider.saveApiKey(_controller.text);
              setState(() => _saved = true);
              Future<void>.delayed(const Duration(seconds: 2), () {
                if (mounted) setState(() => _saved = false);
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  _saved ? AppTheme.successGreen : AppTheme.accentCyan,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(AppTheme.radiusSmall),
              ),
            ),
            child: Icon(
              _saved ? Icons.check_rounded : Icons.save_rounded,
              size: 20,
            ),
          ),
        ),
      ],
    ).animate().fadeIn(duration: 400.ms);
  }
}

// ---------------------------------------------------------------------------
// Unit Toggle
// ---------------------------------------------------------------------------

class _UnitToggle extends StatelessWidget {
  const _UnitToggle({required this.currentUnit, required this.onChanged});
  final SpeedUnit currentUnit;
  final Future<void> Function(SpeedUnit) onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: SpeedUnit.values.map((SpeedUnit unit) {
        final bool selected = unit == currentUnit;
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: GestureDetector(
            onTap: () => onChanged(unit),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: selected
                    ? AppTheme.accentCyan.withValues(alpha: 0.15)
                    : AppTheme.glassFill,
                borderRadius:
                    BorderRadius.circular(AppTheme.radiusSmall),
                border: Border.all(
                  color: selected
                      ? AppTheme.accentCyan
                      : AppTheme.glassBorder,
                ),
              ),
              child: Text(
                unit.label,
                style: GoogleFonts.montserrat(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected
                      ? AppTheme.accentCyan
                      : AppTheme.textSecondary,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    ).animate().fadeIn(duration: 400.ms, delay: 100.ms);
  }
}

// ---------------------------------------------------------------------------
// Model Selector
// ---------------------------------------------------------------------------

class _ModelSelector extends StatelessWidget {
  const _ModelSelector({
    required this.selectedModel,
    required this.onSelected,
  });

  final GeminiModelId selectedModel;
  final Future<void> Function(GeminiModelId) onSelected;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: GeminiModelId.values.length,
      separatorBuilder: (BuildContext ctx, int i) => const SizedBox(height: 6),
      itemBuilder: (BuildContext context, int index) {
        final GeminiModelId model = GeminiModelId.values[index];
        final bool selected = model == selectedModel;
        return GestureDetector(
          onTap: () => onSelected(model),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: selected
                  ? AppTheme.accentCyan.withValues(alpha: 0.1)
                  : AppTheme.glassFill,
              borderRadius:
                  BorderRadius.circular(AppTheme.radiusSmall),
              border: Border.all(
                color: selected
                    ? AppTheme.accentCyan
                    : AppTheme.glassBorder,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  selected
                      ? Icons.check_circle_rounded
                      : Icons.circle_outlined,
                  size: 18,
                  color: selected
                      ? AppTheme.accentCyan
                      : AppTheme.textSecondary,
                ),
                const SizedBox(width: 10),
                Text(
                  model.displayName,
                  style: GoogleFonts.montserrat(
                    fontSize: 13,
                    fontWeight:
                        selected ? FontWeight.w600 : FontWeight.w400,
                    color: selected
                        ? AppTheme.accentCyan
                        : AppTheme.textPrimary,
                  ),
                ),
                const Spacer(),
                Text(
                  model.apiId,
                  style: GoogleFonts.firaCode(
                    fontSize: 9,
                    color: AppTheme.textSecondary.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
        )
            .animate()
            .fadeIn(duration: 300.ms, delay: (index * 50).ms);
      },
    );
  }
}

// ---------------------------------------------------------------------------
// About Card
// ---------------------------------------------------------------------------

class _AboutCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.glassFill,
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        border: Border.all(color: AppTheme.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Car Dashboard',
            style: GoogleFonts.montserrat(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Version 1.0.0 • Build 1',
            style: GoogleFonts.montserrat(
              fontSize: 11,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Android Head Unit Launcher',
            style: GoogleFonts.montserrat(
              fontSize: 11,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 200.ms);
  }
}

// ---------------------------------------------------------------------------
// OBD-II Connection Card
// ---------------------------------------------------------------------------

class _ObdConnectionCard extends StatefulWidget {
  const _ObdConnectionCard({required this.provider});
  final DashboardProvider provider;

  @override
  State<_ObdConnectionCard> createState() => _ObdConnectionCardState();
}

class _ObdConnectionCardState extends State<_ObdConnectionCard> {
  bool _isLoading = false;
  List<BtcDevice> _devices = [];

  Color _statusColor(ObdConnectionStatus status) {
    switch (status) {
      case ObdConnectionStatus.connected:
        return AppTheme.successGreen;
      case ObdConnectionStatus.connecting:
      case ObdConnectionStatus.initializing:
      case ObdConnectionStatus.scanning:
        return AppTheme.alertAmber;
      case ObdConnectionStatus.error:
        return AppTheme.alertRed;
      case ObdConnectionStatus.disconnected:
        return AppTheme.textSecondary;
    }
  }

  Future<void> _autoConnect() async {
    setState(() => _isLoading = true);
    await widget.provider.connectObd();
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _scanDevices() async {
    setState(() => _isLoading = true);
    _devices = await widget.provider.discoverObdDevices();
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _connectToDevice(BtcDevice device) async {
    setState(() => _isLoading = true);
    await widget.provider.connectObdToDevice(device);
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final ObdConnectionStatus status = widget.provider.obdStatus;
    final bool isConnected = status == ObdConnectionStatus.connected;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.glassFill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status row
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _statusColor(status),
                  boxShadow: [
                    BoxShadow(
                      color: _statusColor(status).withValues(alpha: 0.5),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                status.label,
                style: GoogleFonts.montserrat(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _statusColor(status),
                ),
              ),
              const Spacer(),
              if (widget.provider.isLiveObd)
                Text(
                  'LIVE',
                  style: GoogleFonts.montserrat(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.successGreen,
                    letterSpacing: 2,
                  ),
                ),
            ],
          ),
          if (status == ObdConnectionStatus.error && widget.provider.obdErrorMessage != null)
            Padding(
              padding: const EdgeInsets.only(top: 8, left: 18),
              child: Text(
                widget.provider.obdErrorMessage!,
                style: GoogleFonts.montserrat(
                  fontSize: 10,
                  color: AppTheme.alertRed,
                ),
              ),
            ),
          const SizedBox(height: 16),

          // Action buttons
          if (_isLoading)
            const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else if (isConnected)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => widget.provider.disconnectObd(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.alertRed,
                  side: const BorderSide(color: AppTheme.alertRed),
                ),
                child: const Text('Disconnect'),
              ),
            )
          else ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _autoConnect,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentCyan,
                  foregroundColor: Colors.black,
                ),
                child: const Text('Auto Connect (OBDII)'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _scanDevices,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.textSecondary,
                  side: const BorderSide(color: AppTheme.glassBorder),
                ),
                child: const Text('Scan for Devices'),
              ),
            ),
          ],

          // Device list
          if (_devices.isNotEmpty && !isConnected) ...[
            const SizedBox(height: 12),
            Text(
              'Found ${_devices.length} device(s):',
              style: GoogleFonts.montserrat(
                fontSize: 11,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            ..._devices.map((BtcDevice device) {
              return InkWell(
                onTap: () => _connectToDevice(device),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      const Icon(Icons.bluetooth, size: 16, color: AppTheme.accentCyan),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          device.displayName.isNotEmpty ? device.displayName : device.address,
                          style: GoogleFonts.montserrat(
                            fontSize: 12,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ),
                      Text(
                        device.address,
                        style: GoogleFonts.montserrat(
                          fontSize: 10,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 300.ms);
  }
}
