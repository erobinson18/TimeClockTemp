import 'package:flutter/material.dart';

import '../../Services/device_config_service.dart';
import '../../../main.dart';
import '../../../widgets/app_background.dart';
import '../../../widgets/logo_header.dart';
import '../mobile/mobile_auth_service_io.dart';
import 'device_type_screen.dart';

class StartupGateScreen extends StatefulWidget {
  const StartupGateScreen({super.key});

  @override
  State<StartupGateScreen> createState() => _StartupGateScreenState();
}

class _StartupGateScreenState extends State<StartupGateScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  String _status = 'Loading device configuration...';

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
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
    _routeNext();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _routeNext() async {
    await Future.delayed(const Duration(milliseconds: 550));
    if (!mounted) return;

    if (DeviceConfigService.isWallTabletConfigured) {
      setState(() {
        _status = 'Wall tablet configured. Opening time clock...';
      });

      await Future.delayed(const Duration(milliseconds: 250));
      if (!mounted) return;

      Navigator.of(context).pushReplacementNamed(Routes.tablet);
      return;
    }

    if (DeviceConfigService.isMobileConfigured) {
      setState(() {
        _status = 'Checking mobile sign-in...';
      });

      final hasSession =
      await MobileAuthService.instance.hasStoredMobileSession();

      if (!mounted) return;

      if (hasSession) {
        setState(() {
          _status = 'Mobile session found. Opening time clock...';
        });

        MobileAuthService.instance.refreshIfPossible();

        await Future.delayed(const Duration(milliseconds: 250));
        if (!mounted) return;

        Navigator.of(context).pushReplacementNamed(Routes.tablet);
        return;
      }

      setState(() {
        _status = 'Mobile session expired. Returning to setup...';
      });

      await DeviceConfigService.clearLoginStateOnly();

      await Future.delayed(const Duration(milliseconds: 250));
      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => const DeviceTypeScreen(),
        ),
      );
      return;
    }

    setState(() {
      _status = 'Device setup required...';
    });

    await Future.delayed(const Duration(milliseconds: 250));
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => const DeviceTypeScreen(),
      ),
    );
  }

  double _cardWidth(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    if (width < 520) return width - 32;
    if (width < 900) return width - 48;

    return 680;
  }

  double _scaleFor(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    if (width < 420) return 0.82;
    if (width < 700) return 0.90;
    if (width > 1400) return 1.08;

    return 1.0;
  }

  @override
  Widget build(BuildContext context) {
    final scale = _scaleFor(context);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          const AppBackground(overlayOpacity: 0.68),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(18),
                child: FadeTransition(
                  opacity: _fade,
                  child: ScaleTransition(
                    scale: _scale,
                    child: Container(
                      width: _cardWidth(context),
                      padding: EdgeInsets.all(28 * scale),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.52),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.14),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.40),
                            blurRadius: 24,
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
                          SizedBox(height: 28 * scale),
                          SizedBox(
                            width: 34 * scale,
                            height: 34 * scale,
                            child: const CircularProgressIndicator(
                              strokeWidth: 3,
                            ),
                          ),
                          SizedBox(height: 18 * scale),
                          Text(
                            _status,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16 * scale,
                              fontWeight: FontWeight.w800,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
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