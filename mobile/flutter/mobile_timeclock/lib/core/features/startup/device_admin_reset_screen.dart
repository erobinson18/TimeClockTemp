import 'package:flutter/material.dart';

import '../../Services/device_config_service.dart';
import '../mobile/mobile_auth_service.dart';
import '../../../main.dart';
import '../../../widgets/logo_header.dart';

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
      if (DeviceConfigService.deviceMode == DeviceMode.mobile) {
        await MobileAuthService.instance.signOut();
      } else {
        await DeviceConfigService.clearLoginStateOnly();
      }

      if (!mounted) return;

      setState(() {
        _busy = false;
        _statusText = 'Device session cleared. Returning to startup.';
      });

      await Future.delayed(const Duration(milliseconds: 350));
      if (!mounted) return;

      Navigator.of(context).pushNamedAndRemoveUntil(
        Routes.tablet,
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
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: (isError ? Colors.red : Colors.green).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (isError ? Colors.red : Colors.green)
              .withValues(alpha: 0.28),
          width: 2,
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.92),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: AnimatedPadding(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: EdgeInsets.only(
            left: 18,
            right: 18,
            top: 18,
            bottom: keyboard > 0 ? 18 : 18,
          ),
          child: Center(
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: FadeTransition(
                opacity: _fade,
                child: ScaleTransition(
                  scale: _scale,
                  child: Container(
                    width: 760,
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
                                    : () => Navigator.of(context).pop(),
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
                          'Admin Device Reset',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'This clears the current device login/setup state and returns the app to the startup selection screen.',
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
                        const SizedBox(height: 22),
                        TextField(
                          controller: _codeController,
                          obscureText: true,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _confirmReset(),
                          style: const TextStyle(
                            color: Colors.white,
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
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                color: Colors.white.withValues(alpha: 0.14),
                                width: 2,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
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
                          ),
                        if (_statusText != null)
                          _banner(
                            text: _statusText!,
                            isError: false,
                          ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: 320,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _busy ? null : _confirmReset,
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
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: Colors.white,
                              ),
                            )
                                : const Text(
                              'Clear Device Login',
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
}