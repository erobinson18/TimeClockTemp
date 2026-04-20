import 'package:xml/xml.dart';

import '../../core/api_client.dart';
import '../../core/Services/device_config_service.dart';

import '../models/employee_directory_item.dart';
import '../models/punch.dart';
import '../models/status.dart';
import '../models/sync.dart';
import '../models/verify.dart';
import '../models/validate_code.dart';

class TimeClockApi {
  final ApiClient _client;
  TimeClockApi(this._client);

  String get _base => DeviceConfigService.baseUrl;
  String get _auth => DeviceConfigService.authToken;

  // String get _runtimeDeviceId => DeviceConfigService.runtimeDeviceIdentity;
  String get _auditMacAddress => DeviceConfigService.deviceAuditIdentity;
  String get _auditDescription => DeviceConfigService.auditDescription;

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
        employeeId: empNum,
        employeeNumber: empNum,
        fullName: name,
      ));
    }

    return out;
  }

  // =====================
  // Verify (compat)
  // =====================
  Future<VerifyResponse> verify(String employeeNumber) async {
    final emp = employeeNumber.trim();
    if (emp.isEmpty) {
      return const VerifyResponse(
        isValid: false,
        employeeId: null,
        employeeNumber: null,
        fullName: null,
        isClockedIn: false,
      );
    }

    final roster = await rosterAll();
    final match = roster.where((e) => e.employeeNumber.trim() == emp).toList();

    if (match.isEmpty) {
      return const VerifyResponse(
        isValid: false,
        employeeId: null,
        employeeNumber: null,
        fullName: null,
        isClockedIn: false,
      );
    }

    final e = match.first;
    return VerifyResponse(
      isValid: true,
      employeeId: e.employeeId,
      employeeNumber: e.employeeNumber,
      fullName: e.fullName,
      isClockedIn: false,
    );
  }

  // =====================
  // GetStatus
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

  Future<StatusResponse> status(String empId, {String otCode = ''}) async {
    final nowLocal = DateTime.now();

    final effectiveOtCode = otCode.trim().isNotEmpty ? otCode : _auditDescription;

    final raw = await getStatusRaw(
      empId: empId,
      macAddress: _auditMacAddress,
      currTime: _isoLocalNoMillis(nowLocal),
      otCode: effectiveOtCode,
    );

    final parsed = _parseGetStatus(raw);

    return StatusResponse(
      isClockedIn: parsed.isClockedIn,
      fullName: parsed.fullName,
      rawStatus: parsed.rawStatus,
    );
  }

  _ParsedStatus _parseGetStatus(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return const _ParsedStatus(
        isClockedIn: false,
        fullName: null,
        rawStatus: null,
      );
    }

    if (trimmed.contains(';')) {
      final parts = trimmed.split(';');
      final namePart = parts.isNotEmpty ? parts[0].trim() : '';
      final statusPart = parts.length > 1 ? parts[1].trim() : '';

      final normalized = statusPart.toUpperCase();
      final isIn = normalized == 'IN';
      final isOut = normalized == 'OUT';

      if (isIn || isOut) {
        return _ParsedStatus(
          isClockedIn: isIn,
          fullName: namePart.isEmpty ? null : namePart,
          rawStatus: normalized,
        );
      }

      final generic = _genericStatusDetect(trimmed);
      return _ParsedStatus(
        isClockedIn: generic.isClockedIn,
        fullName: namePart.isEmpty ? null : namePart,
        rawStatus: generic.rawStatus,
      );
    }

    return _genericStatusDetect(trimmed);
  }

  _ParsedStatus _genericStatusDetect(String raw) {
    final t = raw.trim();
    final upper = t.toUpperCase();

    if (t == '1') {
      return const _ParsedStatus(
        isClockedIn: true,
        fullName: null,
        rawStatus: 'IN',
      );
    }

    if (t == '0') {
      return const _ParsedStatus(
        isClockedIn: false,
        fullName: null,
        rawStatus: 'OUT',
      );
    }

    final containsIn = upper.contains('IN');
    final containsOut = upper.contains('OUT');

    if (containsIn && !containsOut) {
      return const _ParsedStatus(
        isClockedIn: true,
        fullName: null,
        rawStatus: 'IN',
      );
    }

    if (containsOut && !containsIn) {
      return const _ParsedStatus(
        isClockedIn: false,
        fullName: null,
        rawStatus: 'OUT',
      );
    }

    return _ParsedStatus(
      isClockedIn: false,
      fullName: null,
      rawStatus: upper.isEmpty ? null : upper,
    );
  }

  // =====================
  // CollectPunches
  // =====================
  Future<String> collectPunchesRaw({
    required String empId,
    required String punchTime,
    required String macAddress,
    required String description,
    String otCode = '',
  }) async {
    final effectiveOtCode = otCode.trim().isNotEmpty ? otCode : description;

    final xml = await _client.postForm(_ep('CollectPunches'), {
      'EmpID': empId,
      'PunchTime': punchTime,
      'MACAddress': macAddress,
      'Description': description,
      'Auth': _auth,
      'OTCode': effectiveOtCode,
    });

    return _extractStringValue(xml);
  }

  Future<void> punch(PunchRequest req, {String otCode = ''}) async {
    final punchTimeLocal = _isoLocalNoMillis(req.timestampUtc.toLocal());
    final effectiveOtCode = otCode.trim().isNotEmpty ? otCode : req.description;

    await collectPunchesRaw(
      empId: req.employeeId,
      punchTime: punchTimeLocal,
      macAddress: req.macAddress,
      description: req.description,
      otCode: effectiveOtCode,
    );
  }

  Future<StatusResponse> punchAndGetStatus(
      PunchRequest req, {
        String otCode = '',
      }) async {
    await punch(req, otCode: otCode);
    await Future.delayed(const Duration(milliseconds: 150));

    final effectiveOtCode = otCode.trim().isNotEmpty ? otCode : req.description;
    return status(req.employeeId, otCode: effectiveOtCode);
  }

  // =====================
  // SyncBatch
  // =====================
  Future<SyncResult> syncBatch(SyncPunchBatch batch, {String otCode = ''}) async {
    final accepted = <int>[];
    int processed = 0;

    for (final p in batch.punches) {
      try {
        final punchTimeLocal = _isoLocalNoMillis(p.timestampUtc.toLocal());
        final effectiveOtCode = otCode.trim().isNotEmpty ? otCode : _auditDescription;

        await collectPunchesRaw(
          empId: p.employeeId,
          punchTime: punchTimeLocal,
          macAddress: _auditMacAddress,
          description: _auditDescription,
          otCode: effectiveOtCode,
        );

        accepted.add(p.localSequenceNumber);
        processed++;
      } catch (_) {}
    }

    return SyncResult(processed: processed, acceptedSeq: accepted);
  }

  // =====================
  // ValidateCode
  // =====================
  Future<String> validateCodeRaw({
    required String otCode,
    required String action,
  }) async {
    final xml = await _client.postForm(_ep('ValidateCode'), {
      'OTCode': otCode,
      'Auth': _auth,
      'Action': action,
    });

    return _extractStringValue(xml);
  }

  Future<ValidateCodeResponse> validateCode({
    required String otCode,
    required String action,
  }) async {
    final raw = await validateCodeRaw(
      otCode: otCode,
      action: action,
    );

    final v = raw.trim().toLowerCase();
    final ok = (v == 'success' || v == 'true' || v == '1');

    return ValidateCodeResponse(
      ok: ok,
      rawMessage: raw.trim(),
    );
  }

  // =====================
  // Helpers
  // =====================
  String _isoLocalNoMillis(DateTime local) {
    final dt = local;
    final yyyy = dt.year.toString().padLeft(4, '0');
    final mm = dt.month.toString().padLeft(2, '0');
    final dd = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    final ss = dt.second.toString().padLeft(2, '0');
    return '$yyyy-$mm-$dd'
        'T$hh:$min:$ss';
  }

  String _extractStringValue(String xmlText) {
    final doc = XmlDocument.parse(xmlText);

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

class _ParsedStatus {
  final bool isClockedIn;
  final String? fullName;
  final String? rawStatus;

  const _ParsedStatus({
    required this.isClockedIn,
    required this.fullName,
    required this.rawStatus,
  });
}