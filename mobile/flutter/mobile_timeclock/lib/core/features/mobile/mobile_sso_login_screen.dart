import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../Services/device_config_service.dart';
import '../../../widgets/logo_header.dart';
import '../../../main.dart';

class MobileSsoLoginScreen extends StatefulWidget {
  const MobileSsoLoginScreen({super.key});

  @override
  State<MobileSsoLoginScreen> createState() => _MobileSsoLoginScreenState();
}

class _MobileSsoLoginScreenState extends State<MobileSsoLoginScreen>
    with SingleTickerProviderStateMixin {
  static const String _tenantLoginUrl =
      'https://login.microsoftonline.com/f8371d35-d7a9-4fc1-8735-c18315f9d2dd/saml2?SAMLRequest=fZJdT8IwFIb%2FStP7fQIyGzYyIcQlqIQNL7wxXVegydrOng713zs2SfBCbs85Pc%2BT93Q2%2F5I1OnEDQqsYB66PEVdMV0IdYrwrVk6E58kMqKwbkrb2qLb8o%2BVgUfdOAekbMW6NIpqCAKKo5EAsI3n6tCah65PGaKuZrjHKljF%2BZ2EZTvfML6toH9GIhqOxX7LSrwJWTstJidHrxSY822QALc8UWKpsV%2FLDO8cfO6FfBPckGJEgesNo84t4EGoQv%2BVTDkNAHoti42xe8gKjFIAb20EXWkErucm5OQnGd9t1jI%2FWNkA8rwWHNsKVQnJGwbpMS6%2FWB6G8cwp4SIn0vuYqnts29ELGyS0OgPYWuzwNwlE6uZ95V6jLdZ673dlyo2vBvtFKG0nt%2F%2BjADfqKqJx9P0q4pKJOq8pwgC6QutafC8Op5TG2puUYecmA%2FfsPkh8%3D&RelayState=https%3A%2F%2Fus-api.mimecast.com%2Flogin%2Fsaml';

  final TextEditingController _emailController = TextEditingController();
  final FocusNode _emailFocus = FocusNode();

  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _scale;
  late final Animation<Offset> _slide;

  bool _openingMicrosoft = false;
  bool _continuing = false;
  bool _microsoftOpened = false;
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
    _emailController.dispose();
    _emailFocus.dispose();
    _controller.dispose();
    super.dispose();
  }

  String _normalizeEmail(String value) {
    return value.trim().toLowerCase();
  }

  bool _isValidTsgEmail(String email) {
    final v = _normalizeEmail(email);
    return v.isNotEmpty &&
        v.contains('@') &&
        RegExp(r'^[^@\s]+@tsg\.bz$').hasMatch(v);
  }

  Future<void> _openMicrosoftLogin() async {
    setState(() {
      _openingMicrosoft = true;
      _errorText = null;
      _statusText = null;
    });

    try {
      final uri = Uri.parse(_tenantLoginUrl);

      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!mounted) return;

      if (!launched) {
        setState(() {
          _openingMicrosoft = false;
          _errorText = 'Unable to open the Microsoft sign-in page.';
        });
        return;
      }

      setState(() {
        _openingMicrosoft = false;
        _microsoftOpened = true;
        _statusText =
        'Microsoft sign-in page opened. After signing in, return here and continue with your company email.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _openingMicrosoft = false;
        _errorText = 'Failed to launch Microsoft sign-in: $e';
      });
    }
  }

  Future<void> _continueIntoApp() async {
    final email = _normalizeEmail(_emailController.text);

    setState(() {
      _continuing = true;
      _errorText = null;
      _statusText = null;
    });

    if (!_isValidTsgEmail(email)) {
      setState(() {
        _continuing = false;
        _errorText = 'Enter a valid @tsg.bz email address.';
      });
      return;
    }

    await DeviceConfigService.configureAsMobile(
      displayName: email,
      email: email,
    );

    if (!mounted) return;

    setState(() {
      _continuing = false;
      _statusText = 'Mobile access configured for $email';
    });

    Navigator.of(context).pushNamedAndRemoveUntil(
      Routes.tablet,
          (route) => false,
    );
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
          height: 1.35,
        ),
      ),
    );
  }

  Widget _buildCard() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = constraints.maxWidth >= 900 ? 820.0 : 720.0;

        return Container(
          width: cardWidth,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.12),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.45),
                blurRadius: 24,
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
                      onTap: _openingMicrosoft || _continuing
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
              const SizedBox(height: 6),
              const LogoHeader(
                heightFactor: 0.18,
                padding: EdgeInsets.zero,
                maxHeight: 150,
                minHeight: 90,
              ),
              const SizedBox(height: 18),
              const Text(
                'Mobile Sign-In',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Temporary mobile access flow.\nOpen the Microsoft login page, sign in with your company account, then return here and continue with your @tsg.bz email.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.75),
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 26),
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
                      size: 40,
                      color: Colors.white.withValues(alpha: 0.90),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Microsoft 365',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'This opens your TSG Microsoft tenant sign-in page in the browser for now.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.72),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: 320,
                      height: 56,
                      child: ElevatedButton.icon(
                        onPressed:
                        _openingMicrosoft || _continuing ? null : _openMicrosoftLogin,
                        icon: _openingMicrosoft
                            ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Colors.white,
                          ),
                        )
                            : const Icon(Icons.open_in_new_rounded),
                        label: Text(
                          _openingMicrosoft
                              ? 'Opening...'
                              : 'Open Microsoft Sign-In',
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
              ),
              const SizedBox(height: 22),
              TextField(
                controller: _emailController,
                focusNode: _emailFocus,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _continueIntoApp(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
                decoration: InputDecoration(
                  labelText: 'Company Email',
                  hintText: 'name@tsg.bz',
                  labelStyle:
                  TextStyle(color: Colors.white.withValues(alpha: 0.72)),
                  hintStyle:
                  TextStyle(color: Colors.white.withValues(alpha: 0.34)),
                  prefixIcon: Icon(
                    Icons.mail_outline_rounded,
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
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _microsoftOpened
                      ? 'After signing in in the browser, return here and press Continue.'
                      : 'Use your TSG email address to continue.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.68),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
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
              const SizedBox(height: 22),
              SizedBox(
                width: 300,
                height: 56,
                child: ElevatedButton(
                  onPressed: _openingMicrosoft || _continuing ? null : _continueIntoApp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    disabledBackgroundColor:
                    Colors.white.withValues(alpha: 0.40),
                    disabledForegroundColor: Colors.black54,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: _continuing
                      ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: Colors.black,
                    ),
                  )
                      : const Text(
                    'Continue to Time Clock',
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
      },
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
                child: SlideTransition(
                  position: _slide,
                  child: ScaleTransition(
                    scale: _scale,
                    child: _buildCard(),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}