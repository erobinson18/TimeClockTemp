import 'package:flutter/material.dart';

// import '../../Services/device_config_service.dart';
import '../../../widgets/logo_header.dart';
import '../../../main.dart';
import 'mobile_auth_service.dart';

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
  String? _message;

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

  Future<void> _handleMicrosoftSignIn() async {
    setState(() {
      _busy = true;
      _message = null;
    });

    final result = await MobileAuthService.instance.signIn();

    if (!mounted) return;

    if (!result.ok) {
      setState(() {
        _busy = false;
        _message = result.message;
      });
      return;
    }

    setState(() {
      _busy = false;
      _message = result.message;
    });

    Navigator.of(context).pushNamedAndRemoveUntil(
      Routes.tablet,
          (route) => false,
    );
  }

  Widget _messageBanner() {
    if (_message == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 16),
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
            maxHeight: 150,
            minHeight: 86,
          ),
          const SizedBox(height: 18),
          const Text(
            "Mobile Login",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            "Sign in using Microsoft 365 to configure this device as a personal mobile clock in point.",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 15,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 28),
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
                Icon(
                  Icons.business_center_rounded,
                  color: Colors.white.withValues(alpha: 0.86),
                  size: 42,
                ),
                const SizedBox(height: 12),
                const Text(
                  "Microsoft 365 Sign-In",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "This signs the user in with Microsoft and stores the mobile user's email for the timeclock device profile.",
                  textAlign: TextAlign.center,
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
          _messageBanner(),
          const SizedBox(height: 24),
          SizedBox(
            width: 320,
            height: 58,
            child: ElevatedButton.icon(
              onPressed: _busy ? null : _handleMicrosoftSignIn,
              icon: _busy
                  ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: Colors.white,
                ),
              )
                  : const Icon(Icons.login_rounded),
              label: Text(
                _busy ? "Signing In..." : "Log in with Microsoft 365",
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
                disabledBackgroundColor:
                Colors.red.shade600.withValues(alpha: 0.45),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
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