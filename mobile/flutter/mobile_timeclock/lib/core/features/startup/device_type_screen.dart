import 'package:flutter/material.dart';
import '../../api_client.dart';
import '../../services/device_config_service.dart';
import 'vista_auth_service.dart';
import '../../../widgets/logo_header.dart';
import '../../../widgets/app_background.dart';
import '../../../main.dart';
import '../mobile/mobile_sso_login_screen.dart';
class DeviceTypeScreen extends StatefulWidget {
  const DeviceTypeScreen({super.key});
  @override
  State<DeviceTypeScreen> createState() => _DeviceTypeScreenState();
}
class _DeviceTypeScreenState extends State<DeviceTypeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fade;
  late Animation<double> _scale;
  late Animation<Offset> _slide;
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
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white.withValues(alpha: 0.10),
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(
              color: Colors.white.withValues(alpha: 0.14),
              width: 2,
            ),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.red.shade600,
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withValues(alpha: 0.22),
                    blurRadius: 18,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Icon(icon, size: 34, color: Colors.white),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
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
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
  Widget _buildCard() {
    return Container(
      width: 860,
      margin: const EdgeInsets.symmetric(vertical: 16),
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.48),
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
          const LogoHeader(
            heightFactor: 0.26,
            padding: EdgeInsets.zero,
            maxHeight: 210,
            minHeight: 100,
          ),
          const SizedBox(height: 18),
          const Text(
            'Choose Device Type',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Select how this device will be used before continuing to the time clock.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.76),
              fontSize: 16,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 28),
          _deviceCard(
            title: 'Mobile Clock In Point',
            subtitle:
            'For personal devices using a TSG email. This will be used for mobile employee access.',
            icon: Icons.phone_android_rounded,
            onPressed: _selectMobile,
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
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'OR',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.68),
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
            title: 'Wall Mounted Tablet',
            subtitle:
            'For a dedicated fixed tablet using the assigned Vista access code for that clock location.',
            icon: Icons.tablet_mac_rounded,
            onPressed: _selectWallTablet,
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
          const AppBackground(),
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
                              child: _buildCard(),
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
  late AnimationController _animationController;
  late Animation<double> _fade;
  late Animation<double> _scale;
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
  Widget _buildCard() {
    return Container(
      width: 760,
      margin: const EdgeInsets.symmetric(vertical: 16),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.50),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.14),
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
                  onTap: _busy ? null : () => Navigator.of(context).pop(),
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
            heightFactor: 0.26,
            padding: EdgeInsets.zero,
            maxHeight: 200,
            minHeight: 100,
          ),
          const SizedBox(height: 18),
          const Text(
            'Register Wall Mounted Tablet',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Enter the Vista access code assigned to this tablet location. This code must validate before the device can continue.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.76),
              fontSize: 16,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _controller,
            focusNode: _focusNode,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _register(),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 18,
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
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.14),
                  width: 2,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.28),
                  width: 2,
                ),
              ),
            ),
          ),
          if (_errorText != null) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.red.withValues(alpha: 0.28),
                  width: 2,
                ),
              ),
              child: Text(
                _errorText!,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.92),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: 280,
            height: 58,
            child: ElevatedButton(
              onPressed: _busy ? null : _register,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: _busy
                  ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: Colors.white,
                ),
              )
                  : const Text(
                'Validate & Register',
                style: TextStyle(
                  fontSize: 17,
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
          const AppBackground(),
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
                            child: _buildCard(),
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