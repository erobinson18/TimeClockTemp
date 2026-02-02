import 'package:dio/dio.dart';
import 'config.dart';

class ApiClient {
  final Dio dio;

  ApiClient()
      : dio = Dio(BaseOptions(
          baseUrl: AppConfig.baseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 15),
          headers: {'Content-Type': 'application/json'},
        ));
}