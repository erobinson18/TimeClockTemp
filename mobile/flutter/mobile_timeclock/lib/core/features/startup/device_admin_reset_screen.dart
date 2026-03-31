import 'package:flutter/material.dart';

import '../../services/device_config_service.dart';
import '../../../widgets/logo_header.dart';
import '../../../main.dart';

class DeviceAdminResetScreen extends StatefulWidget {
  const DeviceAdminResetScreen({super.key});

  @override
  State<DeviceAdminResetScreen> createState() => _DeviceAdminResetScreenState();
}

class _DeviceAdminResetScreenState extends State<DeviceAdminResetScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _scale;
  late final Animation<Offset> _slide;

  bool _busy = false;
  String? _message;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
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

    _slide = Tween<Offset>(
      begin: const Offset(0, 0.03),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
      ),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _modeLabel() {
    switch (DeviceConfigService.deviceMode) {
      case DeviceMode.wallTablet:
        return "Wall Mounted Tablet";
      case DeviceMode.mobile:
        return "Mobile Clock In Point";
      case DeviceMode.none:
        return "Not Configured";
    }
  }

  Future<void> _resetToStartup() async {
    setState(() {
      _busy = true;
      _message = null;
    });

    try {
      await DeviceConfigService.clearLoginStateOnly();

      if (!mounted) return;

      Navigator.of(context).pushNamedAndRemoveUntil(
        Routes.startup,
            (route) => false,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _message = "Unable to reset device setup right now.";
      });
    }
  }

  Future<void> _fullResetToDefaults() async {
    setState(() {
      _busy = true;
      _message = null;
    });

    try {
      await DeviceConfigService.resetToDefaults();

      if (!mounted) return;

      Navigator.of(context).pushNamedAndRemoveUntil(
        Routes.startup,
            (route) => false,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _message = "Unable to fully reset this device.";
      });
    }
  }

  Future<void> _confirmReset({
    required String title,
    required String body,
    required Future<void> Function() onConfirm,
    required bool destructive,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: !_busy,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF111111),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: Colors.white.withValues(alpha: 0.14),
              width: 2,
            ),
          ),
          title: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          content: Text(
            body,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.82),
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(
                "Cancel",
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.80),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                destructive ? Colors.red.shade600 : Colors.white,
                foregroundColor: destructive ? Colors.white : Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                destructive ? "Reset" : "Confirm",
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (ok == true) {
      await onConfirm();
    }
  }

  Widget _infoPill(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),
          width: 2,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 170,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.66),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? "(not set)" : value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
    bool destructive = false,
  }) {
    final accent = destructive ? Colors.red.shade600 : Colors.white;

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: _busy ? null : onTap,
      child: Ink(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.12),
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: destructive
                    ? Colors.red.shade600.withValues(alpha: 0.18)
                    : Colors.white.withValues(alpha: 0.10),
                border: Border.all(
                  color: destructive
                      ? Colors.red.shade600.withValues(alpha: 0.50)
                      : Colors.white.withValues(alpha: 0.18),
                  width: 2,
                ),
              ),
              alignment: Alignment.center,
              child: Icon(
                icon,
                color: accent,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: destructive ? Colors.red.shade400 : Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.72),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.white.withValues(alpha: 0.65),
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  Widget _messageBanner() {
    if (_message == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.red.withValues(alpha: 0.28),
          width: 2,
        ),
      ),
      child: Text(
        _message!,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.92),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildBody() {
    return Container(
      width: 920,
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
          const LogoHeader(
            heightFactor: 0.16,
            padding: EdgeInsets.zero,
            maxHeight: 135,
            minHeight: 82,
          ),
          const SizedBox(height: 14),
          const Text(
            "Device Admin Reset",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            "Use this panel to reset the current device login/setup and return to the startup screen.",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 15,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 22),
          _infoPill("Current Mode", _modeLabel()),
          const SizedBox(height: 10),
          _infoPill("Device ID", DeviceConfigService.deviceId),
          const SizedBox(height: 10),
          _infoPill("Wall Tablet Access Code",
              DeviceConfigService.wallTabletAccessCode),
          const SizedBox(height: 10),
          _infoPill("Mobile User", DeviceConfigService.mobileDisplayName),
          const SizedBox(height: 10),
          _infoPill("Mobile Email", DeviceConfigService.mobileEmail),
          _messageBanner(),
          const SizedBox(height: 22),
          _actionButton(
            title: "Reset Login / Setup",
            subtitle:
            "Clears the current mobile or wall-tablet registration and returns the device to the startup selection screen.",
            icon: Icons.logout_rounded,
            onTap: () => _confirmReset(
              title: "Reset Login / Setup?",
              body:
              "This will remove the current device setup and return the app to the startup selection screen.",
              onConfirm: _resetToStartup,
              destructive: false,
            ),
          ),
          const SizedBox(height: 14),
          _actionButton(
            title: "Full Device Reset",
            subtitle:
            "Clears login/setup plus saved defaults for device configuration and returns to startup.",
            icon: Icons.restart_alt_rounded,
            destructive: true,
            onTap: () => _confirmReset(
              title: "Full Device Reset?",
              body:
              "This will clear device setup and reset saved defaults. Use this only when you want to fully re-register the device.",
              onConfirm: _fullResetToDefaults,
              destructive: true,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: 220,
            height: 54,
            child: ElevatedButton(
              onPressed: _busy
                  ? null
                  : () {
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _busy
                  ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: Colors.black,
                ),
              )
                  : const Text(
                "Close",
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
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
      body: SafeArea(
        child: Center(
          child: FadeTransition(
            opacity: _fade,
            child: SlideTransition(
              position: _slide,
              child: ScaleTransition(
                scale: _scale,
                child: _buildBody(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
