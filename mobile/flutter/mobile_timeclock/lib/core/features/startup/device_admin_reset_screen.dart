import 'package:flutter/material.dart';

import '../../Services/device_config_service.dart';
import '../../../main.dart';
import '../../../widgets/app_background.dart';
import '../../../widgets/logo_header.dart';
import '../mobile/mobile_auth_service.dart';

class DeviceAdminResetScreen extends StatefulWidget {
  const DeviceAdminResetScreen({super.key});

  @override
  State<DeviceAdminResetScreen> createState() => _DeviceAdminResetScreenState();
}

class _DeviceAdminResetScreenState extends State<DeviceAdminResetScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _codeController = TextEditingController();

  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  bool _busy = false;
  String? _errorText;
  String? _statusText;

  static const String _adminCode = '009876';

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
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
    _codeController.dispose();
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

    return 760;
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

  Future<void> _confirmReset() async {
    final entered = _codeController.text.trim();

    setState(() {
      _errorText = null;
      _statusText = null;
    });

    if (entered != _adminCode) {
      setState(() {
        _errorText = 'Invalid admin code.';
      });
      return;
    }

    setState(() {
      _busy = true;
    });

    try {
      await MobileAuthService.instance.signOut();
      await DeviceConfigService.clearLoginStateOnly();

      if (!mounted) return;

      setState(() {
        _busy = false;
        _statusText = 'Device login cleared. Returning to startup...';
      });

      await Future.delayed(const Duration(milliseconds: 450));
      if (!mounted) return;

      Navigator.of(context).pushNamedAndRemoveUntil(
        Routes.startup,
            (route) => false,
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _busy = false;
        _errorText = 'Reset failed: $e';
      });
    }
  }

  Widget _banner({
    required String text,
    required bool isError,
    required double scale,
  }) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(top: 14 * scale),
      padding: EdgeInsets.symmetric(
        horizontal: 14 * scale,
        vertical: 12 * scale,
      ),
      decoration: BoxDecoration(
        color: (isError ? Colors.red : Colors.green).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16 * scale),
        border: Border.all(
          color:
          (isError ? Colors.red : Colors.green).withValues(alpha: 0.28),
          width: 2,
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.92),
          fontSize: 14 * scale,
          fontWeight: FontWeight.w700,
          height: 1.35,
        ),
      ),
    );
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
          LogoHeader(
            heightFactor: 0.22,
            padding: EdgeInsets.zero,
            maxHeight: 160 * scale,
            minHeight: 80 * scale,
          ),
          SizedBox(height: 16 * scale),
          Text(
            'Admin Device Reset',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 30 * scale,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 10 * scale),
          Text(
            'This clears the mobile session, wall tablet setup, saved login mode, and returns the app to startup.',
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
          SizedBox(height: 22 * scale),
          TextField(
            controller: _codeController,
            obscureText: true,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            enabled: !_busy,
            onSubmitted: (_) => _confirmReset(),
            style: TextStyle(
              color: Colors.white,
              fontSize: 16 * scale,
              fontWeight: FontWeight.w700,
            ),
            decoration: InputDecoration(
              labelText: 'Confirm Admin Code',
              hintText: 'Enter 009876',
              labelStyle: TextStyle(
                color: Colors.white.withValues(alpha: 0.72),
              ),
              hintStyle: TextStyle(
                color: Colors.white.withValues(alpha: 0.34),
              ),
              prefixIcon: Icon(
                Icons.lock_outline_rounded,
                color: Colors.white.withValues(alpha: 0.78),
              ),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.07),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16 * scale),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.14),
                  width: 2,
                ),
              ),
              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16 * scale),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.10),
                  width: 2,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16 * scale),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.28),
                  width: 2,
                ),
              ),
            ),
          ),
          if (_errorText != null)
            _banner(
              text: _errorText!,
              isError: true,
              scale: scale,
            ),
          if (_statusText != null)
            _banner(
              text: _statusText!,
              isError: false,
              scale: scale,
            ),
          SizedBox(height: 24 * scale),
          SizedBox(
            width: 320 * scale,
            height: 56 * scale,
            child: ElevatedButton(
              onPressed: _busy ? null : _confirmReset,
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
                'Fully Reset Device Login',
                textAlign: TextAlign.center,
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
              child: Center(
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                  ScrollViewKeyboardDismissBehavior.onDrag,
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
          ),
        ],
      ),
    );
  }
}