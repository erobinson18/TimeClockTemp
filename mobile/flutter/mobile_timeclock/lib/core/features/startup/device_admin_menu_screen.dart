import 'package:flutter/material.dart';

import '../../Services/device_config_service.dart';
import '../../../widgets/logo_header.dart';
import 'device_admin_reset_screen.dart';

class DeviceAdminMenuScreen extends StatefulWidget {
  final Future<void> Function(BuildContext context) openServiceSettings;

  const DeviceAdminMenuScreen({
    super.key,
    required this.openServiceSettings,
  });

  @override
  State<DeviceAdminMenuScreen> createState() => _DeviceAdminMenuScreenState();
}

class _DeviceAdminMenuScreenState extends State<DeviceAdminMenuScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );

    _fade = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );

    _scale = Tween<double>(begin: 0.97, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutBack,
      ),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _modeLabel {
    switch (DeviceConfigService.deviceMode) {
      case DeviceMode.wallTablet:
        return 'Wall Mounted Tablet';
      case DeviceMode.mobile:
        return 'Mobile Clock In Point';
      case DeviceMode.none:
        return 'Not Configured';
    }
  }

  String get _identityLabel {
    if (DeviceConfigService.deviceMode == DeviceMode.wallTablet) {
      return DeviceConfigService.wallTabletAccessCode;
    }
    if (DeviceConfigService.deviceMode == DeviceMode.mobile) {
      return DeviceConfigService.mobileEmail;
    }
    return '';
  }

  Future<void> _openServiceSettings() async {
    await widget.openServiceSettings(context);
  }

  Future<void> _openDeviceReset() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const DeviceAdminResetScreen(),
      ),
    );
  }

  Widget _actionButton({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
    Color? fillColor,
    Color? foregroundColor,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 84,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: fillColor ?? Colors.white.withValues(alpha: 0.10),
          foregroundColor: foregroundColor ?? Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: Colors.white.withValues(alpha: 0.14),
              width: 2,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.10),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.14),
                  width: 2,
                ),
              ),
              child: Icon(icon, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: (foregroundColor ?? Colors.white)
                          .withValues(alpha: 0.78),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 18,
              color: (foregroundColor ?? Colors.white).withValues(alpha: 0.85),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      children: [
        SizedBox(
          width: 150,
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.68),
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: FadeTransition(
            opacity: _fade,
            child: ScaleTransition(
              scale: _scale,
              child: Container(
                width: 780,
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                    width: 2,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(999),
                            onTap: () => Navigator.of(context).pop(),
                            child: Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.18),
                                  width: 2,
                                ),
                                color: Colors.white.withValues(alpha: 0.06),
                              ),
                              child: Icon(
                                Icons.arrow_back_rounded,
                                color: Colors.white.withValues(alpha: 0.92),
                              ),
                            ),
                          ),
                        ),
                        const Spacer(),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const LogoHeader(
                      heightFactor: 0.18,
                      padding: EdgeInsets.zero,
                      maxHeight: 150,
                      minHeight: 90,
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Admin Menu',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Use the options below to manage service settings or clear the device login/setup state.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 22),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.12),
                          width: 2,
                        ),
                      ),
                      child: Column(
                        children: [
                          _infoRow('Current Mode', _modeLabel),
                          const SizedBox(height: 10),
                          _infoRow(
                            'Current Identity',
                            _identityLabel.isEmpty ? '(none)' : _identityLabel,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    _actionButton(
                      title: 'Service Settings',
                      subtitle: 'Update the service URL and authentication token.',
                      icon: Icons.settings_rounded,
                      onTap: _openServiceSettings,
                    ),
                    const SizedBox(height: 16),
                    _actionButton(
                      title: 'Device Reset / Logout',
                      subtitle:
                      'Clear device login/setup and return to startup.',
                      icon: Icons.logout_rounded,
                      onTap: _openDeviceReset,
                      fillColor: Colors.red.shade600,
                      foregroundColor: Colors.white,
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: 220,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: const Text(
                          'Close',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}