import 'package:flutter/material.dart';

import '../../Services/device_config_service.dart';
import '../../../widgets/logo_header.dart';
import '../../../main.dart';
import 'device_type_screen.dart';

class StartupGateScreen extends StatefulWidget {
  const StartupGateScreen({super.key});

  @override
  State<StartupGateScreen> createState() => _StartupGateScreenState();
}

class _StartupGateScreenState extends State<StartupGateScreen> {
  @override
  void initState() {
    super.initState();
    _routeNext();
  }

  Future<void> _routeNext() async {
    await Future.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;

    if (DeviceConfigService.isWallTabletConfigured) {
      Navigator.of(context).pushReplacementNamed(Routes.tablet);
      return;
    }

    if (DeviceConfigService.isMobileConfigured) {
      Navigator.of(context).pushReplacementNamed(Routes.tablet);
      return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => const DeviceTypeScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: SizedBox(
            width: 460,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                LogoHeader(
                  heightFactor: 0.22,
                  padding: EdgeInsets.zero,
                  maxHeight: 180,
                  minHeight: 90,
                ),
                SizedBox(height: 28),
                CircularProgressIndicator(),
                SizedBox(height: 18),
                Text(
                  "Loading device configuration...",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}