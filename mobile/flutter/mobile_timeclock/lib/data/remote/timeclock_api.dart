import '../../core/api_client.dart';
import '../../core/app_config.dart';

import '../models/punch.dart';
import '../models/status.dart';
import '../models/sync.dart';
import '../models/verify.dart';

class TimeClockApi {
  TimeClockApi(this._client);

  final ApiClient _client;

  Future<void> ping() async {
    await getEmps();
  }

  // ────────────────────────────────────────────────────────────────────────────
  // ASMX: GetEmps(Auth) -> string
  // ────────────────────────────────────────────────────────────────────────────
  Future<String> getEmps() async {
    final raw = await _client.getText("GetEmps", query: {
      "Auth": AppConfig.authToken,
    });

    return _extractAsmxString(raw);
  }

  /// Returns roster items for caching (TabletScreen warmupRoster uses toJson()).
  Future<List<RosterItem>> rosterAll() async {
    final raw = await getEmps();
    final emps = _parseEmployees(raw);

    return emps
        .map((e) => RosterItem(
              employeeId: e.empId,
              employeeNumber: e.empId,
              fullName: e.fullName,
            ))
        .toList();
  }

  // ────────────────────────────────────────────────────────────────────────────
  // "Verify" (front-end concept):
  // We verify an EmpID exists by checking GetEmps result, then GetStatus for truth.
  // ────────────────────────────────────────────────────────────────────────────
  Future<VerifyResponse> verify(String employeeNumber) async {
    final emps = _parseEmployees(await getEmps());
    final match = emps.where((e) => e.empId == employeeNumber).toList();

    if (match.isEmpty) {
      return const VerifyResponse(
        isValid: false,
        employeeId: null,
        employeeNumber: null,
        fullName: null,
        isClockedIn: false,
      );
    }

    final s = await status(employeeNumber);

    return VerifyResponse(
      isValid: true,
      employeeId: employeeNumber,
      employeeNumber: employeeNumber,
      fullName: match.first.fullName,
      isClockedIn: s.isClockedIn,
    );
  }

  // ────────────────────────────────────────────────────────────────────────────
  // ASMX: GetStatus(EmpID, MACAddress, CurrTime, Auth, OTCode) -> string
  // ────────────────────────────────────────────────────────────────────────────
  Future<StatusResponse> status(String employeeGuidOrId) async {
    final raw = await _client.getText("GetStatus", query: {
      "EmpID": employeeGuidOrId,
      "MACAddress": AppConfig.kioskId,
      "CurrTime": TimeFormats.nowForBackend(),
      "Auth": AppConfig.authToken,
      "OTCode": AppConfig.otCode,
    });

    final result = _extractAsmxString(raw);
    return StatusResponse.fromRaw(result);
  }

  // ────────────────────────────────────────────────────────────────────────────
  // ASMX: CollectPunches(EmpID, PunchTime, MACAddress, Auth, OTCode) -> string
  // ────────────────────────────────────────────────────────────────────────────
  Future<void> punch(PunchRequest req) async {
    final raw = await _client.getText("CollectPunches", query: {
      "EmpID": req.employeeId,
      "PunchTime": TimeFormats.toBackendString(req.timestampUtc.toLocal()),
      "MACAddress": AppConfig.kioskId,
      "Auth": AppConfig.authToken,
      "OTCode": AppConfig.otCode,
    });

    final result = _extractAsmxString(raw);
    final ok = _isOkResult(result);

    if (!ok) {
      throw Exception("CollectPunches failed: $result");
    }
  }

  // If batching isn't supported, send each punch.
  Future<SyncResult> syncBatch(SyncPunchBatch batch) async {
    int processed = 0;
    final accepted = <int>[];

    for (final p in batch.punches) {
      final raw = await _client.getText("CollectPunches", query: {
        "EmpID": p.employeeId,
        "PunchTime": TimeFormats.toBackendString(p.timestampUtc.toLocal()),
        "MACAddress": AppConfig.kioskId,
        "Auth": AppConfig.authToken,
        "OTCode": AppConfig.otCode,
      });

      final result = _extractAsmxString(raw);
      if (_isOkResult(result)) {
        processed++;
        accepted.add(p.localSequenceNumber);
      }
    }

    return SyncResult(processed: processed, acceptedSeq: accepted);
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Helpers
  // ────────────────────────────────────────────────────────────────────────────

  bool _isOkResult(String s) {
    final r = s.trim().toLowerCase();
    return !(r.contains("error") || r.contains("fail") || r.contains("invalid"));
  }

  String _extractAsmxString(String body) {
    final b = body.trim();
    if (!b.startsWith("<")) return b;

    // extract inner contents of <string>...</string> or similar
    final open = b.indexOf(">");
    final close = b.lastIndexOf("</");
    if (open != -1 && close != -1 && close > open) {
      return b.substring(open + 1, close).trim();
    }

    return b;
  }

  List<_Emp> _parseEmployees(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return [];

    // service may separate rows by newline | pipe | semicolon
    final rows = trimmed
        .split(RegExp(r'[\r\n\|;]+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final out = <_Emp>[];

    for (final row in rows) {
      // expected "12345,John Doe"
      final parts = row.split(",");
      if (parts.length < 2) continue;

      final id = parts[0].trim();
      final name = parts.sublist(1).join(",").trim();

      if (id.isEmpty || name.isEmpty) continue;
      out.add(_Emp(empId: id, fullName: name));
    }

    return out;
  }
}

class _Emp {
  final String empId;
  final String fullName;
  const _Emp({required this.empId, required this.fullName});
}

class RosterItem {
  final String employeeId;
  final String employeeNumber;
  final String fullName;

  const RosterItem({
    required this.employeeId,
    required this.employeeNumber,
    required this.fullName,
  });

  Map<String, dynamic> toJson() => {
        "employeeId": employeeId,
        "employeeNumber": employeeNumber,
        "fullName": fullName,
      };
}

class TimeFormats {
  static String toBackendString(DateTime local) {
    final mm = local.month.toString().padLeft(2, "0");
    final dd = local.day.toString().padLeft(2, "0");
    final yyyy = local.year.toString();

    int h = local.hour;
    final ampm = h >= 12 ? "PM" : "AM";
    h = h % 12;
    if (h == 0) h = 12;

    final hh = h.toString();
    final min = local.minute.toString().padLeft(2, "0");
    final sec = local.second.toString().padLeft(2, "0");

    return "$mm/$dd/$yyyy $hh:$min:$sec $ampm";
  }

  static String nowForBackend() => toBackendString(DateTime.now());
}