import 'package:flutter/material.dart';

import '../../Services/device_config_service.dart';
import '../../../widgets/app_background.dart';
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

  double _screenScale(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    if (width < 420) return 0.78;
    if (width < 700) return 0.88;
    if (width > 1400) return 1.08;

    return 1.0;
  }

  double _cardWidth(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    if (width < 520) return width - 32;
    if (width < 900) return width - 48;

    return 780;
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

    if (!mounted) return;
    setState(() {});
  }

  Widget _infoRow({
    required String label,
    required String value,
    required double scale,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 150 * scale,
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.68),
              fontSize: 14 * scale,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white,
              fontSize: 15 * scale,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }

  Widget _actionButton({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
    required double scale,
    Color? fillColor,
    Color? foregroundColor,
  }) {
    final fg = foregroundColor ?? Colors.white;

    return SizedBox(
      width: double.infinity,
      height: 84 * scale,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: fillColor ?? Colors.white.withValues(alpha: 0.10),
          foregroundColor: fg,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20 * scale),
            side: BorderSide(
              color: Colors.white.withValues(alpha: 0.14),
              width: 2,
            ),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: 18 * scale,
            vertical: 14 * scale,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 46 * scale,
              height: 46 * scale,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.10),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.14),
                  width: 2,
                ),
              ),
              child: Icon(
                icon,
                size: 24 * scale,
              ),
            ),
            SizedBox(width: 16 * scale),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 19 * scale,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 4 * scale),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13 * scale,
                      fontWeight: FontWeight.w600,
                      color: fg.withValues(alpha: 0.78),
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 10 * scale),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 18 * scale,
              color: fg.withValues(alpha: 0.85),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(BuildContext context) {
    final scale = _screenScale(context);

    return Container(
      width: _cardWidth(context),
      padding: EdgeInsets.all(28 * scale),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.52),
        borderRadius: BorderRadius.circular(30 * scale),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.14),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.40),
            blurRadius: 24 * scale,
            spreadRadius: 2,
          ),
        ],
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
                    width: 46 * scale,
                    height: 46 * scale,
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
                      size: 24 * scale,
                    ),
                  ),
                ),
              ),
              const Spacer(),
            ],
          ),
          LogoHeader(
            heightFactor: 0.22,
            padding: EdgeInsets.zero,
            maxHeight: 160 * scale,
            minHeight: 80 * scale,
          ),
          SizedBox(height: 16 * scale),
          Text(
            'Admin Menu',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 30 * scale,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 10 * scale),
          Text(
            'Use the options below to manage service settings or fully reset this device login.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 15 * scale,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
          SizedBox(height: 22 * scale),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(18 * scale),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(18 * scale),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.12),
                width: 2,
              ),
            ),
            child: Column(
              children: [
                _infoRow(
                  label: 'Current Mode',
                  value: _modeLabel,
                  scale: scale,
                ),
                SizedBox(height: 10 * scale),
                _infoRow(
                  label: 'Current Identity',
                  value: _identityLabel.isEmpty ? '(none)' : _identityLabel,
                  scale: scale,
                ),
              ],
            ),
          ),
          SizedBox(height: 24 * scale),
          _actionButton(
            title: 'Service Settings',
            subtitle: 'Update the service URL and authentication token.',
            icon: Icons.settings_rounded,
            onTap: _openServiceSettings,
            scale: scale,
          ),
          SizedBox(height: 16 * scale),
          _actionButton(
            title: 'Device Reset / Logout',
            subtitle: 'Clear login, setup, mobile tokens, and return to startup.',
            icon: Icons.logout_rounded,
            onTap: _openDeviceReset,
            fillColor: Colors.red.shade600,
            foregroundColor: Colors.white,
            scale: scale,
          ),
          SizedBox(height: 20 * scale),
          SizedBox(
            width: 220 * scale,
            height: 52 * scale,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18 * scale),
                ),
              ),
              child: Text(
                'Close',
                style: TextStyle(
                  fontSize: 16 * scale,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          const AppBackground(overlayOpacity: 0.68),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.all(18),
                child: FadeTransition(
                  opacity: _fade,
                  child: ScaleTransition(
                    scale: _scale,
                    child: _buildCard(context),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}