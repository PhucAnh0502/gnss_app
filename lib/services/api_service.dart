import 'dart:developer' as developer;
import 'package:dio/dio.dart';
import 'package:gnss_app/constants/app_constants.dart';
import 'package:gnss_app/constants/app_environment.dart';
import 'token_storage_service.dart';
import '../utils/jwt_utils.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal() {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          if (AppEnvironment.isDevelopment) {
            developer.log(
              '[API] ${options.method} ${options.uri}',
              name: 'gnss_app.api',
            );
          }

          final token = await TokenStorageService.getToken();
          if (token != null && token.isNotEmpty && !JwtUtils.isExpired(token)) {
            options.headers['Authorization'] = 'Bearer $token';
          }

          handler.next(options);
        },
        onError: (error, handler) async {
          if (AppEnvironment.isDevelopment) {
            developer.log(
              '[API Error] ${error.message} | ${error.response?.statusCode}',
              name: 'gnss_app.api',
              error: error,
            );
          }

          if (error.response?.statusCode == 401) {
            await TokenStorageService.clearToken();
          }

          handler.next(error);
        },
      ),
    );
  }

  final Dio dio = Dio(
    BaseOptions(
      baseUrl: AppConstants.baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
    ),
  );
}
