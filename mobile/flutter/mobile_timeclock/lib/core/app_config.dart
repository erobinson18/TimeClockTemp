import 'package:flutter/foundation.dart' show kIsWeb;

/// Central place for backend settings.
class AppConfig {
  // ASMX endpoint
  static const String asmxBaseUrl = "https://tcws.tsg.bz/tsgtc.asmx";

  // Web needs a proxy if CORS is not enabled on ASMX.
  // Example: https://your-proxy.azurewebsites.net
  static const String webProxyBaseUrl = "https://REPLACE_WITH_YOUR_PROXY_HOST";

  // If ASMX supports CORS, you can set this false.
  static const bool useProxyOnWeb = true;

  // Your bosses will provide this value.
  static const String authToken = "REPLACE_WITH_REAL_AUTH";

  // Only used if your system requires it.
  static const String otCode = "";

  // Used for MACAddress parameter; we pass a stable kiosk identifier.
  static const String kioskId = "KIOSK-TEST-01";

  static const Duration timeout = Duration(seconds: 12);

  static String get effectiveBaseUrl {
    if (kIsWeb && useProxyOnWeb) return webProxyBaseUrl;
    return asmxBaseUrl;
  }
}