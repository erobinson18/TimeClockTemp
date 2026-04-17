import 'package:flutter/material.dart';

import '../../Services/device_config_service.dart';
import '../../api_client.dart';
import '../../../widgets/logo_header.dart';
import '../../../main.dart';
import 'vista_auth_service.dart';
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
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.14),
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: Colors.red.shade600.withValues(alpha: 0.92),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(
                icon,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.72),
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.white.withValues(alpha: 0.70),
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    return Container(
      width: 860,
      padding: const EdgeInsets.all(24),
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
            heightFactor: 0.16,
            padding: EdgeInsets.zero,
            maxHeight: 120,
            minHeight: 72,
          ),
          const SizedBox(height: 14),
          const Text(
            "Choose Device Type",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Select how this device will be used before continuing to the time clock.",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 14,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 22),
          _deviceCard(
            title: "Mobile Clock In Point",
            subtitle:
            "For personal devices using Microsoft 365 sign-in. This will be used for mobile employee access.",
            icon: Icons.phone_android_rounded,
            onTap: _selectMobile,
          ),
          const SizedBox(height: 16),
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
          const SizedBox(height: 16),
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
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 40,
                ),
                child: Center(
                  child: FadeTransition(
                    opacity: _fade,
                    child: SlideTransition(
                      position: _slide,
                      child: ScaleTransition(
                        scale: _scale,
                        child: _buildBody(context),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
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
  final ScrollController _scrollController = ScrollController();

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

    _codeFocus.addListener(_handleFocusChange);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _codeFocus.requestFocus();
      }
    });
  }

  void _handleFocusChange() {
    if (_codeFocus.hasFocus) {
      Future.delayed(const Duration(milliseconds: 250), () {
        if (!mounted) return;
        if (!_scrollController.hasClients) return;

        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
        );
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _codeController.dispose();
    _codeFocus.removeListener(_handleFocusChange);
    _codeFocus.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _showStartupServiceSettingsDialog() async {
    final urlCtrl = TextEditingController(text: DeviceConfigService.baseUrl);
    final authCtrl = TextEditingController(text: DeviceConfigService.authToken);

    bool busy = false;
    String? inlineStatus;
    String? inlineError;

    Future<({bool ok, String message})> testServiceSettings({
      required String baseUrl,
      required String authToken,
    }) async {
      final url = baseUrl.trim();
      final auth = authToken.trim();

      if (url.isEmpty) {
        return (ok: false, message: "Base URL is required.");
      }

      if (auth.isEmpty) {
        return (ok: false, message: "Auth token is required.");
      }

      try {
        final client = await ApiClient.pinned(
          pemAssetPath: 'assets/certs/tsg_cert.pem',
          log: (m) => debugPrint(m),
          allowedHosts: const {'apply.tsg.bz', 'tcws.tsg.bz', 'tsg.bz'},
        );

        final xml = await client.postForm('$url/GetEmps', {'Auth': auth});
        final value = _extractSoapStringValue(xml);

        if (value.trim().isEmpty) {
          return (
          ok: false,
          message: "Server responded, but returned an empty value.",
          );
        }

        final looksLikeHtml =
            value.toLowerCase().contains('<html') || xml.toLowerCase().contains('<html');

        if (looksLikeHtml) {
          return (
          ok: false,
          message: "Endpoint looks wrong (HTML response). Check the .asmx path.",
          );
        }

        return (ok: true, message: "Verified and saved.");
      } catch (e) {
        return (ok: false, message: "Verify failed: $e");
      }
    }

    if (!mounted) return;

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: "dialog",
      barrierColor: Colors.black.withValues(alpha: 0.65),
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (ctx, a1, a2) {
        return SafeArea(
          child: Center(
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: 640,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFF111111),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.14),
                    width: 2,
                  ),
                ),
                child: StatefulBuilder(
                  builder: (ctx, setLocal) {
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                "Startup Service Settings",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.of(ctx).pop(),
                              icon: Icon(
                                Icons.close,
                                color: Colors.white.withValues(alpha: 0.85),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: urlCtrl,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                          decoration: InputDecoration(
                            labelText: "Service Base URL",
                            hintText: "https://tcws.tsg.bz/tsgtc.asmx",
                            labelStyle:
                            TextStyle(color: Colors.white.withValues(alpha: 0.75)),
                            hintStyle:
                            TextStyle(color: Colors.white.withValues(alpha: 0.35)),
                            filled: true,
                            fillColor: Colors.white.withValues(alpha: 0.07),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                color: Colors.white.withValues(alpha: 0.16),
                                width: 2,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                color: Colors.white.withValues(alpha: 0.30),
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: authCtrl,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                          decoration: InputDecoration(
                            labelText: "Auth Token",
                            hintText: "",
                            labelStyle:
                            TextStyle(color: Colors.white.withValues(alpha: 0.75)),
                            hintStyle:
                            TextStyle(color: Colors.white.withValues(alpha: 0.35)),
                            filled: true,
                            fillColor: Colors.white.withValues(alpha: 0.07),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                color: Colors.white.withValues(alpha: 0.16),
                                width: 2,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                color: Colors.white.withValues(alpha: 0.30),
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                        if (inlineError != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: Colors.red.withValues(alpha: 0.35),
                                width: 2,
                              ),
                            ),
                            child: Text(
                              inlineError!,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.90),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                        if (inlineStatus != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: Colors.green.withValues(alpha: 0.35),
                                width: 2,
                              ),
                            ),
                            child: Text(
                              inlineStatus!,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.90),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            SizedBox(
                              height: 44,
                              child: ElevatedButton(
                                onPressed: busy ? null : () => Navigator.of(ctx).pop(),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white.withValues(alpha: 0.10),
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text(
                                  "Close",
                                  style: TextStyle(fontWeight: FontWeight.w900),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            SizedBox(
                              height: 44,
                              child: ElevatedButton(
                                onPressed: busy
                                    ? null
                                    : () async {
                                  setLocal(() {
                                    busy = true;
                                    inlineError = null;
                                    inlineStatus = "Testing connection…";
                                  });

                                  final result = await testServiceSettings(
                                    baseUrl: urlCtrl.text,
                                    authToken: authCtrl.text,
                                  );

                                  if (!mounted) return;

                                  if (!result.ok) {
                                    setLocal(() {
                                      busy = false;
                                      inlineStatus = null;
                                      inlineError = result.message;
                                    });
                                    return;
                                  }

                                  await DeviceConfigService.setBaseUrl(urlCtrl.text);
                                  await DeviceConfigService.setAuthToken(authCtrl.text);

                                  setLocal(() {
                                    busy = false;
                                    inlineError = null;
                                    inlineStatus = result.message;
                                  });
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: Colors.black,
                                ),
                                child: const Text(
                                  "Verify & Save",
                                  style: TextStyle(fontWeight: FontWeight.w900),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String _extractSoapStringValue(String xmlText) {
    final match =
    RegExp(r'<string[^>]*>(.*?)</string>', dotAll: true).firstMatch(xmlText);

    if (match == null) return '';

    final inner = match.group(1) ?? '';
    return inner
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .trim();
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
      final client = await ApiClient.pinned(
        pemAssetPath: 'assets/certs/tsg_cert.pem',
        log: (m) => debugPrint(m),
        allowedHosts: const {'apply.tsg.bz', 'tcws.tsg.bz', 'tsg.bz'},
      );

      final service = VistaAuthService(client);
      final result = await service.validateNewSetupCode(code);

      if (!mounted) return;

      if (!result.ok) {
        setState(() {
          _busy = false;
          _error = result.message.isEmpty
              ? "Invalid access code."
              : result.message;
        });
        return;
      }

      await DeviceConfigService.configureAsWallTablet(accessCode: code);

      if (!mounted) return;

      Navigator.of(context).pushNamedAndRemoveUntil(
        Routes.tablet,
            (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = "Unable to register this tablet: $e";
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
      padding: const EdgeInsets.all(24),
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
                    width: 44,
                    height: 44,
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
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: _busy ? null : _showStartupServiceSettingsDialog,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.18),
                        width: 2,
                      ),
                      color: Colors.white.withValues(alpha: 0.06),
                    ),
                    child: Icon(
                      Icons.settings_rounded,
                      color: Colors.white.withValues(alpha: 0.92),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const LogoHeader(
            heightFactor: 0.15,
            padding: EdgeInsets.zero,
            maxHeight: 110,
            minHeight: 68,
          ),
          const SizedBox(height: 12),
          const Text(
            "Register Wall Mounted Tablet",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Enter the Vista access code assigned to this tablet location. This will link the device to its dedicated clock point.",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 14,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 18),
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
          const SizedBox(height: 18),
          SizedBox(
            width: 260,
            height: 54,
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
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final keyboardOpen = bottomInset > 0;

    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return AnimatedPadding(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: keyboardOpen ? 12 : 20,
                bottom: keyboardOpen ? 12 : 20,
              ),
              child: SingleChildScrollView(
                controller: _scrollController,
                keyboardDismissBehavior:
                ScrollViewKeyboardDismissBehavior.onDrag,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: keyboardOpen
                        ? 0
                        : constraints.maxHeight - 40,
                  ),
                  child: Align(
                    alignment:
                    keyboardOpen ? Alignment.topCenter : Alignment.center,
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
              ),
            );
          },
        ),
      ),
    );
  }
}