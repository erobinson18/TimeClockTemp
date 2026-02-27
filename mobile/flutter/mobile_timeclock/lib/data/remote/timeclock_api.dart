import 'package:xml/xml.dart';

import '../../core/api_client.dart';
import '../../core/Services/device_config_service.dart';
import '../models/employee_directory_item.dart';
import '../models/punch.dart';
import '../models/status.dart';
import '../models/sync.dart';

class TimeClockApi {
  final ApiClient _client;
  TimeClockApi(this._client);

  String get _base => DeviceConfigService.baseUrl; // ex: https://tcws.tsg.bz/tsgtc.asmx
  String get _auth => DeviceConfigService.authToken;
  String get _kioskId => DeviceConfigService.kioskId;

  String _ep(String method) => '$_base/$method';

  Future<void> ping() async {
    await getEmpsRaw();
  }

  // =====================
  // GetEmps
  // =====================
  Future<String> getEmpsRaw() async {
    final xml = await _client.postForm(_ep('GetEmps'), {'Auth': _auth});
    return _extractStringValue(xml);
  }

  Future<List<EmployeeDirectoryItem>> rosterAll() async {
    final raw = await getEmpsRaw();
    return _parseGetEmps(raw);
  }

  List<EmployeeDirectoryItem> _parseGetEmps(String raw) {
    // Raw sample: "1000;Name;100060;LAST, FIRST;..."
    final parts = raw
        .split(';')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final out = <EmployeeDirectoryItem>[];

    for (int i = 0; i + 1 < parts.length; i += 2) {
      final empNum = parts[i];
      final name = parts[i + 1];
      if (empNum.isEmpty || name.isEmpty) continue;

      out.add(EmployeeDirectoryItem(
        employeeId: empNum, // TEMP until real GUID exists
        employeeNumber: empNum,
        fullName: name,
      ));
    }

    return out;
  }

  // =====================
  // GetStatus (Step 2)
  // =====================
  Future<String> getStatusRaw({
    required String empId,
    required String macAddress,
    required String currTime,
    String otCode = '',
  }) async {
    final xml = await _client.postForm(_ep('GetStatus'), {
      'EmpID': empId,
      'MACAddress': macAddress,
      'CurrTime': currTime,
      'Auth': _auth,
      'OTCode': otCode,
    });

    return _extractStringValue(xml);
  }

  Future<StatusResponse> status(String empId) async {
    final nowLocal = DateTime.now();
    final raw = await getStatusRaw(
      empId: empId,
      macAddress: _kioskId,
      currTime: nowLocal.toIso8601String(),
      otCode: '',
    );

    // NOTE: we don’t know the real output format yet.
    // So we interpret common patterns safely:
    // - contains "IN" => clocked in
    // - equals "1" => clocked in
    // - contains "OUT" => clocked out
    final upper = raw.toUpperCase();
    final isIn = upper.contains('IN') || raw.trim() == '1';
    final isOut = upper.contains('OUT') || raw.trim() == '0';

    // If ambiguous, default to cached behavior on UI side
    final bool clockedIn = isIn && !isOut;

    return StatusResponse(isClockedIn: clockedIn);
  }

  // =====================
  // CollectPunches (Step 3)
  // =====================
  Future<String> collectPunchesRaw({
    required String empId,
    required String punchTime,
    required String macAddress,
    String otCode = '',
  }) async {
    final xml = await _client.postForm(_ep('CollectPunches'), {
      'EmpID': empId,
      'PunchTime': punchTime,
      'MACAddress': macAddress,
      'Auth': _auth,
      'OTCode': otCode,
    });

    return _extractStringValue(xml);
  }

  Future<void> punch(PunchRequest req) async {
    // Your web service doesn’t accept punchType directly;
    // it uses PunchTime and server decides IN/OUT.
    // We still queue punchType locally for UX + audit trail.
    await collectPunchesRaw(
      empId: req.employeeId,
      punchTime: req.timestampUtc.toIso8601String(),
      macAddress: _kioskId,
      otCode: '',
    );
  }

  // =====================
  // SyncBatch (Step 4-ish)
  // =====================
  Future<SyncResult> syncBatch(SyncPunchBatch batch) async {
    final accepted = <int>[];
    int processed = 0;

    for (final p in batch.punches) {
      try {
        await collectPunchesRaw(
          empId: p.employeeId,
          punchTime: p.timestampUtc.toIso8601String(),
          macAddress: _kioskId,
          otCode: '',
        );

        accepted.add(p.localSequenceNumber);
        processed++;
      } catch (_) {
        // keep going; we only accept successful seq values
      }
    }

    return SyncResult(
      processed: processed,
      acceptedSeq: accepted,
    );
  }

  // =====================
  // SOAP <string> parser
  // =====================
  String _extractStringValue(String xmlText) {
    final doc = XmlDocument.parse(xmlText);

    // Finds <string xmlns="..."> regardless of namespace
    XmlElement? node;
    for (final e in doc.descendants.whereType<XmlElement>()) {
      if (e.name.local == 'string') {
        node = e;
        break;
      }
    }
    return (node?.innerText ?? '').trim();
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}