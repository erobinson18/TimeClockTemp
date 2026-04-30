import 'package:flutter/material.dart';

import '../../../main.dart';
import '../../../widgets/app_background.dart';
import '../../../widgets/logo_header.dart';
import 'mobile_auth_service_io.dart';

class MobileSsoLoginScreen extends StatefulWidget {
  const MobileSsoLoginScreen({super.key});

  @override
  State<MobileSsoLoginScreen> createState() => _MobileSsoLoginScreenState();
}

class _MobileSsoLoginScreenState extends State<MobileSsoLoginScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _scale;
  late final Animation<Offset> _slide;

  bool _busy = false;
  String? _errorText;
  String? _statusText;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
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

    return 820;
  }

  Future<void> _signIn() async {
    if (_busy) return;

    setState(() {
      _busy = true;
      _errorText = null;
      _statusText = null;
    });

    final result = await MobileAuthService.instance.signIn();

    if (!mounted) return;

    if (!result.ok) {
      setState(() {
        _busy = false;
        _errorText = result.message;
      });
      return;
    }

    setState(() {
      _busy = false;
      _statusText = 'Signed in as ${result.email}';
    });

    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    Navigator.of(context).pushNamedAndRemoveUntil(
      Routes.tablet,
          (route) => false,
    );
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
            'Microsoft Sign-In',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 34 * scale,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 10 * scale),
          Text(
            'Sign in with your TSG Microsoft 365 account to access the mobile time clock.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.76),
              fontSize: 16 * scale,
              fontWeight: FontWeight.w600,
              height: 1.45,
            ),
          ),
          SizedBox(height: 26 * scale),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(20 * scale),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(22 * scale),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.12),
                width: 2,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.business_center_rounded,
                  color: Colors.white.withValues(alpha: 0.90),
                  size: 42 * scale,
                ),
                SizedBox(height: 12 * scale),
                Text(
                  'Microsoft 365',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24 * scale,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 8 * scale),
                Text(
                  'This opens the secure Microsoft sign-in flow and returns directly to the app.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.72),
                    fontSize: 14 * scale,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
                SizedBox(height: 18 * scale),
                SizedBox(
                  width: 340 * scale,
                  height: 58 * scale,
                  child: ElevatedButton.icon(
                    onPressed: _busy ? null : _signIn,
                    icon: _busy
                        ? SizedBox(
                      width: 18 * scale,
                      height: 18 * scale,
                      child: const CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    )
                        : Icon(
                      Icons.login_rounded,
                      size: 22 * scale,
                    ),
                    label: Text(
                      _busy ? 'Signing In...' : 'Sign In with Microsoft',
                      style: TextStyle(
                        fontSize: 16 * scale,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade600,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor:
                      Colors.red.shade600.withValues(alpha: 0.45),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18 * scale),
                      ),
                    ),
                  ),
                ),
              ],
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