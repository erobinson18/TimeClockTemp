import '../../core/api_client.dart';
import '../models/verify.dart';
import '../models/status.dart';
import '../models/punch.dart';

class TimeClockApi {
  final ApiClient _client;
  TimeClockApi(this._client);

  Future<VerifyResponse> verify(String employeeId) async {
    final res = await _client.dio.post(
      '/api/verify',
      data: VerifyRequest(employeeId: employeeId).toJson(),
    );
    return VerifyResponse.fromJson(res.data as Map<String, dynamic>);
  }

  Future<StatusResponse> status(String employeeGuid) async {
    final res = await _client.dio.get(
      '/api/status/$employeeGuid');
    return StatusResponse.fromJson(res.data as Map<String, dynamic>);
  }

  Future<void> punch(PunchRequest request) async {
    await _client.dio.post('/api/punch', data: request.toJson());
  }
}