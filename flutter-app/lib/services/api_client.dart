import 'package:dio/dio.dart';
import '../config/api_config.dart';

class ApiClient {
  late final Dio dio;

  ApiClient({String? baseUrl}) {
    dio = Dio(BaseOptions(
      baseUrl: baseUrl ?? ApiConfig.baseUrl,
      connectTimeout: ApiConfig.connectTimeout,
      receiveTimeout: ApiConfig.receiveTimeout,
      headers: {'Content-Type': 'application/json'},
    ));

    dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
      error: true,
    ));
  }

  Future<Response> post(String path, {dynamic data}) async {
    try {
      return await dio.post(path, data: data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Response> get(String path) async {
    try {
      return await dio.get(path);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Exception _handleError(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return Exception('요청 시간 초과');
    } else if (e.type == DioExceptionType.connectionError) {
      return Exception('서버에 연결할 수 없습니다. 백엔드가 실행 중인지 확인하세요.');
    } else if (e.response != null) {
      return Exception('서버 오류: ${e.response?.statusCode}');
    }
    return Exception('네트워크 오류');
  }
}
