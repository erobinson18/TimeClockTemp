import 'package:connectivity_plus/connectivity_plus.dart';
import '../api_client.dart';

class ConnectivityService {
  final Connectivity _connectivity = Connectivity();
  final ApiClient _api;

  ConnectivityService(this._api);

  Future<bool> isOnline() async {
    final result = await _connectivity.checkConnectivity();
    if (result == ConnectivityResult.none) return false;

    try {
      await _api.ping(); // cheap GET
      return true;
    } catch (_) {
      return false;
    }
  }
}
