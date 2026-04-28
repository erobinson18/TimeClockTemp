import 'package:flutter/foundation.dart' show kIsWeb;

/// Central place for backend settings.
/// IMPORTANT:
/// - Web may require a proxy (CORS)
/// - Mobile should use DeviceConfigService (Hive) for BaseUrl/Auth/DeviceId
class AppConfig {
  // Default ASMX endpoint (fallback only)
  static const String defaultAsmxBaseUrl = "https://tcws.tsg.bz/tsgtc.asmx";

  // Web needs a proxy if CORS is not enabled on ASMX.
  // Example: https://your-proxy.azurewebsites.net
  static const String webProxyBaseUrl = "https://REPLACE_WITH_YOUR_PROXY_HOST";

  // If ASMX supports CORS, you can set this false.
  static const bool useProxyOnWeb = true;

  // Only used by web builds if you decide not to store auth in web storage yet.
  // Prefer injecting at build time or using a secure web config later.
  static const String webAuthToken = "";

  // Only used if your system requires it.
  static const String defaultOtCode = "";

  static const Duration timeout = Duration(seconds: 12);

  static String get effectiveBaseUrl {
    if (kIsWeb && useProxyOnWeb) return webProxyBaseUrl;
    return defaultAsmxBaseUrl;
  }
}