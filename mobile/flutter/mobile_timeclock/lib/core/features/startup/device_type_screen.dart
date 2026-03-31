import 'package:flutter/material.dart';

import '../../services/device_config_service.dart';
import '../../../widgets/logo_header.dart';
import '../../../main.dart';
import '../mobile/mobile_sso_login_screen.dart';

class DeviceTypeScreen extends StatefulWidget {
  const DeviceTypeScreen({super.key});

  @override
  State<DeviceTypeScreen> createState() => _DeviceTypeScreenState();
}

class _DeviceTypeScreenState extends State<DeviceTypeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _scale;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );

    _fade = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );

    _scale = Tween<double>(begin: 0.96, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutBack,
      ),
    );

    _slide = Tween<Offset>(
      begin: const Offset(0, 0.035),
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

  Future<void> _selectMobile() async {
    await DeviceConfigService.setDeviceMode(DeviceMode.mobile);
    if (!mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const MobileSsoLoginScreen(),
      ),
    );
  }

  Future<void> _selectWallTablet() async {
    await DeviceConfigService.setDeviceMode(DeviceMode.wallTablet);
    if (!mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const WallTabletAccessScreen(),
      ),
    );
  }

  Widget _deviceCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Ink(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.14),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.22),
              blurRadius: 18,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                color: Colors.red.shade600.withValues(alpha: 0.92),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.shade700.withValues(alpha: 0.28),
                    blurRadius: 16,
                    spreadRadius: 1,
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Icon(
                icon,
                color: Colors.white,
                size: 30,
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
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
            const SizedBox(width: 10),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.white.withValues(alpha: 0.70),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    return Container(
      width: 860,
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
            heightFactor: 0.18,
            padding: EdgeInsets.zero,
            maxHeight: 150,
            minHeight: 86,
          ),
          const SizedBox(height: 18),
          const Text(
            "Choose Device Type",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            "Select how this device will be used before continuing to the time clock.",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 15,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 28),
          _deviceCard(
            title: "Mobile Clock In Point",
            subtitle:
            "For personal devices using Microsoft 365 sign-in. This will be used for mobile employee access.",
            icon: Icons.phone_android_rounded,
            onTap: _selectMobile,
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: Divider(
                  color: Colors.white.withValues(alpha: 0.12),
                  thickness: 1.5,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Text(
                  "OR",
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.52),
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              Expanded(
                child: Divider(
                  color: Colors.white.withValues(alpha: 0.12),
                  thickness: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _deviceCard(
            title: "Wall Mounted Tablet",
            subtitle:
            "For a dedicated fixed tablet using the assigned Vista access code for that clock location.",
            icon: Icons.tablet_mac_rounded,
            onTap: _selectWallTablet,
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

class WallTabletAccessScreen extends StatefulWidget {
  const WallTabletAccessScreen({super.key});

  @override
  State<WallTabletAccessScreen> createState() => _WallTabletAccessScreenState();
}

class _WallTabletAccessScreenState extends State<WallTabletAccessScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _codeController = TextEditingController();
  final FocusNode _codeFocus = FocusNode();

  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _scale;
  late final Animation<Offset> _slide;

  bool _busy = false;
  String? _error;

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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _codeFocus.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _codeController.dispose();
    _codeFocus.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    final code = _codeController.text.trim();

    if (code.isEmpty) {
      setState(() {
        _error = "Enter the tablet access code to continue.";
      });
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await DeviceConfigService.configureAsWallTablet(accessCode: code);

      if (!mounted) return;

      Navigator.of(context).pushNamedAndRemoveUntil(
        Routes.tablet,
            (route) => false,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = "Unable to register this tablet right now.";
      });
    }
  }

  Widget _buildErrorBanner() {
    if (_error == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.red.withValues(alpha: 0.30),
          width: 2,
        ),
      ),
      child: Text(
        _error!,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.92),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildBody() {
    return Container(
      width: 720,
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
                  onTap: _busy
                      ? null
                      : () {
                    Navigator.of(context).pop();
                  },
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
              const Expanded(child: SizedBox()),
            ],
          ),
          const SizedBox(height: 8),
          const LogoHeader(
            heightFactor: 0.18,
            padding: EdgeInsets.zero,
            maxHeight: 140,
            minHeight: 82,
          ),
          const SizedBox(height: 18),
          const Text(
            "Register Wall Mounted Tablet",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            "Enter the Vista access code assigned to this tablet location. This will link the device to its dedicated clock point.",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 15,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 26),
          TextField(
            controller: _codeController,
            focusNode: _codeFocus,
            enabled: !_busy,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _register(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
            ),
            decoration: InputDecoration(
              labelText: "Tablet Access Code",
              hintText: "Enter access code",
              labelStyle: TextStyle(
                color: Colors.white.withValues(alpha: 0.72),
              ),
              hintStyle: TextStyle(
                color: Colors.white.withValues(alpha: 0.35),
              ),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.07),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 18,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.16),
                  width: 2,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.30),
                  width: 2,
                ),
              ),
              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.10),
                  width: 2,
                ),
              ),
            ),
          ),
          _buildErrorBanner(),
          const SizedBox(height: 22),
          SizedBox(
            width: 280,
            height: 56,
            child: ElevatedButton(
              onPressed: _busy ? null : _register,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
                disabledBackgroundColor:
                Colors.red.shade600.withValues(alpha: 0.45),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: _busy
                  ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.6,
                  color: Colors.white,
                ),
              )
                  : const Text(
                "Register Device",
                style: TextStyle(
                  fontSize: 16,
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
