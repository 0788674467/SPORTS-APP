import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// HTTP client for making API requests to the backend.
/// 
/// Automatically attaches JWT tokens from secure storage to requests
/// and handles common error scenarios like token expiration.
class ApiClient {
  /// Dio instance for making HTTP requests
  final Dio dio;
  
  /// Secure storage for JWT tokens
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  /// Creates an API client with the specified base URL.
  /// 
  /// [baseUrl] - The base URL of the backend API (e.g., 'http://localhost:3000/api')
  ApiClient({required String baseUrl})
      : dio = Dio(BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        )) {
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.read(key: 'jwt');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (e, handler) {
        if (e.response?.statusCode == 401) {
          // Handle token expiration / global sign-out
        }
        return handler.next(e);
      },
    ));
  }

  // ─── Generic Request Methods ─────────────────────────────────────────────

  /// Performs a GET request.
  Future<Response> get(String path, {Map<String, dynamic>? queryParameters}) =>
      dio.get(path, queryParameters: queryParameters);

  /// Performs a POST request.
  Future<Response> post(String path, {dynamic data}) =>
      dio.post(path, data: data);

  /// Performs a PUT request.
  Future<Response> put(String path, {dynamic data}) =>
      dio.put(path, data: data);

  /// Performs a DELETE request.
  Future<Response> delete(String path) => dio.delete(path);

  /// Performs a PATCH request.
  Future<Response> patch(String path, {dynamic data}) =>
      dio.patch(path, data: data);
}
