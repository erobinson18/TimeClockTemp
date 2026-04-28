import 'package:flutter/material.dart';

import '../../api_client.dart';
import '../../services/device_config_service.dart';
import '../../../main.dart';
import '../../../widgets/app_background.dart';
import '../../../widgets/logo_header.dart';
import '../mobile/mobile_sso_login_screen.dart';
import 'vista_auth_service.dart';

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
      duration: const Duration(milliseconds: 700),
    );

    _fade = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );

    _scale = Tween<double>(begin: 0.95, end: 1).animate(
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

    return 860;
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
        builder: (_) => const _WallTabletAccessScreen(),
      ),
    );
  }

  Widget _deviceCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onPressed,
    required double scale,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white.withValues(alpha: 0.10),
          foregroundColor: Colors.white,
          elevation: 0,
          padding: EdgeInsets.symmetric(
            horizontal: 20 * scale,
            vertical: 18 * scale,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24 * scale),
            side: BorderSide(
              color: Colors.white.withValues(alpha: 0.14),
              width: 2,
            ),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 64 * scale,
              height: 64 * scale,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.red.shade600,
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withValues(alpha: 0.22),
                    blurRadius: 18 * scale,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Icon(
                icon,
                size: 34 * scale,
                color: Colors.white,
              ),
            ),
            SizedBox(width: 18 * scale),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 19 * scale,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 6 * scale),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14 * scale,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.76),
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.white.withValues(alpha: 0.85),
              size: 18 * scale,
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
      margin: EdgeInsets.symmetric(vertical: 16 * scale),
      padding: EdgeInsets.all(30 * scale),
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
          LogoHeader(
            heightFactor: 0.26,
            padding: EdgeInsets.zero,
            maxHeight: 210 * scale,
            minHeight: 90 * scale,
          ),
          SizedBox(height: 18 * scale),
          Text(
            'Choose Device Type',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 34 * scale,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 10 * scale),
          Text(
            'Select how this device will be used before continuing to the time clock.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.76),
              fontSize: 16 * scale,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
          SizedBox(height: 28 * scale),
          _deviceCard(
            title: 'Mobile Clock In Point',
            subtitle:
            'For personal devices using a TSG Microsoft account. This is used for mobile employee access.',
            icon: Icons.phone_android_rounded,
            onPressed: _selectMobile,
            scale: scale,
          ),
          SizedBox(height: 18 * scale),
          Row(
            children: [
              Expanded(
                child: Divider(
                  color: Colors.white.withValues(alpha: 0.12),
                  thickness: 1.5,
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 12 * scale),
                child: Text(
                  'OR',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.68),
                    fontSize: 14 * scale,
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
          SizedBox(height: 18 * scale),
          _deviceCard(
            title: 'Wall Mounted Tablet',
            subtitle:
            'For a dedicated fixed tablet using the assigned Vista access code for that clock location.',
            icon: Icons.tablet_mac_rounded,
            onPressed: _selectWallTablet,
            scale: scale,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          const AppBackground(overlayOpacity: 0.68),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  keyboardDismissBehavior:
                  ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.all(18),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - 36,
                    ),
                    child: IntrinsicHeight(
                      child: FadeTransition(
                        opacity: _fade,
                        child: SlideTransition(
                          position: _slide,
                          child: ScaleTransition(
                            scale: _scale,
                            child: Center(
                              child: _buildCard(context),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _WallTabletAccessScreen extends StatefulWidget {
  const _WallTabletAccessScreen();

  @override
  State<_WallTabletAccessScreen> createState() => _WallTabletAccessScreenState();
}

class _WallTabletAccessScreenState extends State<_WallTabletAccessScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  late final AnimationController _animationController;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  bool _busy = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );

    _fade = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );

    _scale = Tween<double>(begin: 0.97, end: 1).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutBack,
      ),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _animationController.dispose();
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

    return 760;
  }

  Future<VistaAuthService> _buildVistaAuthService() async {
    final client = await ApiClient.pinned(
      pemAssetPath: 'assets/certs/tsg_cert.pem',
      log: (m) => debugPrint(m),
      allowedHosts: const {'apply.tsg.bz', 'tcws.tsg.bz', 'tsg.bz'},
    );

    return VistaAuthService(client);
  }

  Future<void> _register() async {
    final code = _controller.text.trim();

    setState(() {
      _errorText = null;
    });

    if (code.isEmpty) {
      setState(() {
        _errorText = 'Enter the tablet access code.';
      });
      return;
    }

    setState(() {
      _busy = true;
    });

    try {
      final vistaAuth = await _buildVistaAuthService();
      final result = await vistaAuth.validateNewSetupCode(code);

      if (!mounted) return;

      if (!result.ok) {
        setState(() {
          _busy = false;
          _errorText = result.message;
        });
        return;
      }

      await DeviceConfigService.configureAsWallTablet(accessCode: code);

      if (!mounted) return;

      setState(() {
        _busy = false;
      });

      Navigator.pushReplacementNamed(context, Routes.tablet);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _busy = false;
        _errorText = 'Validation failed: $e';
      });
    }
  }

  Widget _errorBanner(String message, double scale) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: 14 * scale,
        vertical: 12 * scale,
      ),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16 * scale),
        border: Border.all(
          color: Colors.red.withValues(alpha: 0.28),
          width: 2,
        ),
      ),
      child: Text(
        message,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.92),
          fontSize: 14 * scale,
          fontWeight: FontWeight.w700,
          height: 1.35,
        ),
      ),
    );
  }

  Widget _buildCard(BuildContext context) {
    final scale = _screenScale(context);

    return Container(
      width: _cardWidth(context),
      margin: EdgeInsets.symmetric(vertical: 16 * scale),
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
                  onTap: _busy ? null : () => Navigator.of(context).pop(),
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
          SizedBox(height: 8 * scale),
          LogoHeader(
            heightFactor: 0.26,
            padding: EdgeInsets.zero,
            maxHeight: 200 * scale,
            minHeight: 90 * scale,
          ),
          SizedBox(height: 18 * scale),
          Text(
            'Register Wall Mounted Tablet',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 34 * scale,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 10 * scale),
          Text(
            'Enter the Vista access code assigned to this tablet location. This code must validate before the device can continue.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.76),
              fontSize: 16 * scale,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
          SizedBox(height: 24 * scale),
          TextField(
            controller: _controller,
            focusNode: _focusNode,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            enabled: !_busy,
            onSubmitted: (_) => _register(),
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 18 * scale,
            ),
            decoration: InputDecoration(
              labelText: 'Tablet Access Code',
              hintText: 'Enter access code',
              labelStyle: TextStyle(
                color: Colors.white.withValues(alpha: 0.72),
              ),
              hintStyle: TextStyle(
                color: Colors.white.withValues(alpha: 0.34),
              ),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.08),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18 * scale),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.14),
                  width: 2,
                ),
              ),
              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18 * scale),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.10),
                  width: 2,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18 * scale),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.28),
                  width: 2,
                ),
              ),
            ),
          ),
          if (_errorText != null) ...[
            SizedBox(height: 14 * scale),
            _errorBanner(_errorText!, scale),
          ],
          SizedBox(height: 24 * scale),
          SizedBox(
            width: 290 * scale,
            height: 58 * scale,
            child: ElevatedButton(
              onPressed: _busy ? null : _register,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
                disabledBackgroundColor:
                Colors.red.shade600.withValues(alpha: 0.45),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18 * scale),
                ),
              ),
              child: _busy
                  ? SizedBox(
                width: 18 * scale,
                height: 18 * scale,
                child: const CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: Colors.white,
                ),
              )
                  : Text(
                'Validate & Register',
                style: TextStyle(
                  fontSize: 17 * scale,
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
    final keyboard = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          const AppBackground(overlayOpacity: 0.68),
          SafeArea(
            child: AnimatedPadding(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              padding: EdgeInsets.only(
                left: 18,
                right: 18,
                top: 18,
                bottom: keyboard > 0 ? keyboard + 18 : 18,
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: FadeTransition(
                        opacity: _fade,
                        child: ScaleTransition(
                          scale: _scale,
                          child: Center(
                            child: _buildCard(context),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}