import 'package:xml/xml.dart';

import '../../core/api_client.dart';
import '../../core/Services/device_config_service.dart';

import '../models/sync.dart';
import '../models/verify.dart';
import '../models/status.dart';
import '../models/punch.dart';

class TimeClockApi {
  TimeClockApi(this._client);

  final ApiClient _client;

  static const String _ns = "http://tsg.bz/";
  static const String _asmxPath = "/tsgtc.asmx";

  // ===== Connectivity =====
  Future<void> ping() async {
    final endpoint = _endpointUri();
    await _client.ping(endpoint);
  }

  // ===== Step 1: Roster (GetEmps) =====
  Future<List<RosterItem>> rosterAll() async {
    final endpoint = _endpointUri();
    final auth = DeviceConfigService.authToken.trim();

    if (auth.isEmpty) {
      throw Exception("Missing Auth Token (admin settings).");
    }

    final envelope = _soapEnvelope("""
<GetEmps xmlns="$_ns">
  <Auth>${_xmlEscape(auth)}</Auth>
</GetEmps>
""");

    final xmlText = await _client.postSoap(
      url: endpoint,
      soapAction: "${_ns}GetEmps",
      envelopeXml: envelope,
    );

    final raw = _extractResult(xmlText, "GetEmpsResult");
    return _parseGetEmpsPairs(raw);
  }

  // Kept for compatibility (even if TabletScreen no longer calls it)
  Future<VerifyResponse> verify(String employeeNumber) async {
    final roster = await rosterAll();

    final hit = roster.firstWhere(
      (e) => e.employeeNumber.trim() == employeeNumber.trim(),
      orElse: () => const RosterItem(
        employeeId: "",
        employeeNumber: "",
        fullName: "",
      ),
    );

    if (hit.employeeId.isEmpty) {
      // IMPORTANT: VerifyResponse requires all fields
      return const VerifyResponse(
        isValid: false,
        employeeId: "",
        employeeNumber: "",
        fullName: "",
        isClockedIn: false,
      );
    }

    // Until Step 2 (GetStatus) is wired, default isClockedIn to false.
    return VerifyResponse(
      isValid: true,
      employeeId: hit.employeeId,
      employeeNumber: hit.employeeNumber,
      fullName: hit.fullName,
      isClockedIn: false,
    );
  }

  // ===== Step 2 (later): Status =====
  Future<StatusResponse> status(String employeeId) {
    throw UnimplementedError("status() not wired yet (needs GetStatusResult format).");
  }

  // ===== Step 3 (later): Punch =====
  Future<void> punch(PunchRequest req) {
    throw UnimplementedError("punch() not wired yet (needs CollectPunchesResult format).");
  }

  // ===== Sync (later) =====
  Future<SyncResult> syncBatch(SyncPunchBatch batch) {
    throw UnimplementedError("syncBatch() not wired yet (needs backend behavior/format).");
  }

  // ===== Internal helpers =====
  Uri _endpointUri() {
    final raw = DeviceConfigService.baseUrl.trim();
    if (raw.isEmpty) {
      throw Exception("Missing Base URL (admin settings).");
    }

    final uri = Uri.parse(raw);

    final isAsmx = uri.path.toLowerCase().endsWith(".asmx");
    if (isAsmx) return uri;

    return uri.replace(path: _asmxPath);
  }

  String _soapEnvelope(String bodyInnerXml) {
    return """<?xml version="1.0" encoding="utf-8"?>
<soap:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
               xmlns:xsd="http://www.w3.org/2001/XMLSchema"
               xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
  <soap:Body>
$bodyInnerXml
  </soap:Body>
</soap:Envelope>""";
  }

  String _extractResult(String xmlText, String tagName) {
    final doc = XmlDocument.parse(xmlText);
    final node = doc.findAllElements(tagName).firstOrNull;
    if (node == null) return "";
    return node.innerText.trim();
  }

  List<RosterItem> _parseGetEmpsPairs(String raw) {
    // Format: EmpId;Full Name;EmpId;Full Name;...
    if (raw.trim().isEmpty) return [];

    final parts = raw.split(";").map((e) => e.trim()).toList();
    final out = <RosterItem>[];

    for (int i = 0; i + 1 < parts.length; i += 2) {
      final id = parts[i].trim();
      final name = parts[i + 1].trim();

      if (id.isEmpty || name.isEmpty) continue;

      // Employee ID is what user types (can be non-numeric)
      out.add(RosterItem(
        employeeId: id,
        employeeNumber: id,
        fullName: name,
      ));
    }

    return out;
  }

  String _xmlEscape(String value) {
    return value
        .replaceAll("&", "&amp;")
        .replaceAll("<", "&lt;")
        .replaceAll(">", "&gt;")
        .replaceAll('"', "&quot;")
        .replaceAll("'", "&apos;");
  }
}

extension _FirstOrNullExt<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
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