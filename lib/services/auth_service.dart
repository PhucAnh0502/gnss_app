import 'package:dio/dio.dart';

import '../models/user_model.dart';
import 'api_service.dart';
import 'token_storage_service.dart';
import '../utils/jwt_utils.dart';

class AuthService {
  final _api = ApiService().dio;

  Future<UserModel> login(String email, String password) async {
    try {
      final response = await _api.post(
        '/auth/login',
        data: {'email': email, 'password': password},
      );

      final data = response.data as Map<String, dynamic>;
      final token = data['token'] as String?;
      if (token == null || token.isEmpty) {
        throw Exception('Login response missing token');
      }

      await TokenStorageService.saveToken(token);

      final userJson = data['user'];
      if (userJson is Map<String, dynamic>) {
        return UserModel.fromJson(userJson, token: token);
      }

      return UserModel.empty(token: token);
    } catch (e) {
      throw Exception(_extractErrorMessage(e));
    }
  }

  Future<void> register(
    String username,
    String email,
    String password,
    String confirmPassword,
  ) async {
    try {
      await _api.post(
        '/auth/register',
        data: {
          'username': username,
          'email': email,
          'password': password,
          'confirmPassword': confirmPassword,
        },
      );
    } catch (e) {
      throw Exception(_extractErrorMessage(e));
    }
  }

  Future<void> forgotPassword(String email) async {
    try {
      await _api.post('/auth/forgot-password', data: {'email': email});
    } catch (e) {
      throw Exception(_extractErrorMessage(e));
    }
  }

  Future<void> verifyResetOtp({
    required String email,
    required String otp,
  }) async {
    try {
      await _api.post(
        '/auth/verify-reset-otp',
        data: {'email': email, 'otp': otp},
      );
    } catch (e) {
      throw Exception(_extractErrorMessage(e));
    }
  }

  Future<void> resetPassword({
    required String email,
    required String otp,
    required String password,
    required String confirmPassword,
  }) async {
    try {
      await _api.put(
        '/auth/reset-password',
        data: {
          'email': email,
          'otp': otp,
          'password': password,
          'confirmPassword': confirmPassword,
        },
      );
    } catch (e) {
      throw Exception(_extractErrorMessage(e));
    }
  }

  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    try {
      await _api.put(
        '/auth/change-password',
        data: {
          'oldPassword': oldPassword,
          'newPassword': newPassword,
          'confirmPassword': confirmPassword,
        },
      );
    } catch (e) {
      throw Exception(_extractErrorMessage(e));
    }
  }

  Future<bool> hasValidToken() async {
    final token = await TokenStorageService.getToken();
    if (token == null || token.isEmpty) {
      return false;
    }

    return !JwtUtils.isExpired(token);
  }

  Future<void> logout() {
    return TokenStorageService.clearToken();
  }

  String _extractErrorMessage(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map<String, dynamic>) {
        final errors = data['errors'];
        if (errors is List && errors.isNotEmpty) {
          final messages = <String>[];
          for (final item in errors) {
            if (item is Map<String, dynamic>) {
              final message = item['message']?.toString();
              if (message != null && message.isNotEmpty) {
                messages.add(message);
              }
            }
          }
          if (messages.isNotEmpty) {
            return messages.join('\n');
          }
        }

        final message = data['message']?.toString();
        if (message != null && message.isNotEmpty) {
          return message;
        }
      }

      return error.message ?? 'Request failed. Please try again.';
    }

    return error.toString();
  }
}
