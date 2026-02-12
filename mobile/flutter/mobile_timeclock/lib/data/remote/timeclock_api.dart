import '../../core/api_client.dart';
import '../models/verify.dart';
import '../models/status.dart';
import '../models/punch.dart';
import '../models/sync.dart';
import '../models/employee_directory_item.dart';

class TimeClockApi {
  final ApiClient _client;
  TimeClockApi(this._client);

  Future<VerifyResponse> verify(String employeeNumber) async {
    final res = await _client.dio.post(
      '/api/verify',
      data: VerifyRequest(employeeNumber: employeeNumber).toJson(),
    );

    return VerifyResponse.fromJson(res.data as Map<String, dynamic>);
  }

  Future<StatusResponse> status(String employeeGuid) async {
    final res = await _client.dio.get('/api/status/$employeeGuid');
    return StatusResponse.fromJson(res.data as Map<String, dynamic>);
  }

  Future<void> punch(PunchRequest request) async {
    await _client.dio.post('/api/punch', data: request.toJson());
  }

  Future<SyncBatchResponse> syncBatch(SyncPunchBatch batch) async {
    final res = await _client.dio.post('/api/sync/batch', data: batch.toJson());
    return SyncBatchResponse.fromJson(res.data as Map<String, dynamic>);
  }

  Future<void> ping() async {
    await _client.dio.get('/api/health/ping');
  }

  Future<List<EmployeeDirectoryItem>> rosterAll() async {
    final res = await _client.dio.get('/api/roster/all');
    final list = (res.data as List).cast<Map<String, dynamic>>();
    return list.map(EmployeeDirectoryItem.fromJson).toList();
  }
}
