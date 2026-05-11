import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class DiagnosticService {
  final _dio = Dio();

  Future<bool> testHttpConnection() async {
    try {
      final baseUrl = dotenv.env['BASE_API_URL']?.trim();
      if (baseUrl == null || baseUrl.isEmpty) {
        print('[Diagnostic] BASE_API_URL is missing');
        return false;
      }

      print('[Diagnostic] Testing HTTP connection to: $baseUrl');
      final response = await _dio.get(
        baseUrl,
        options: Options(validateStatus: (status) => status != null),
      ).timeout(
        const Duration(seconds: 5),
      );

      print('[Diagnostic] HTTP response status: ${response.statusCode}');
      return response.statusCode != null && response.statusCode! < 500;
    } catch (e) {
      print('[Diagnostic] HTTP connection failed: $e');
      return false;
    }
  }

  Future<String> getBackendUrl() async {
    final baseUrl = dotenv.env['BASE_API_URL']?.trim() ?? 'Not configured';
    return baseUrl;
  }

  Future<void> logNetworkInfo() async {
    try {
      final baseUrl = dotenv.env['BASE_API_URL']?.trim();
      print('[Diagnostic] ========== Network Info ==========');
      print('[Diagnostic] BASE_API_URL: $baseUrl');
      
      if (baseUrl != null) {
        final uri = Uri.tryParse(baseUrl);
        if (uri != null) {
          print('[Diagnostic] API Host: ${uri.host}');
          print('[Diagnostic] API Port: ${uri.port}');
          print('[Diagnostic] API Scheme: ${uri.scheme}');
          
          final wsScheme = uri.scheme == 'https' ? 'wss' : 'ws';
          final wsUrl = '$wsScheme://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}';
          print('[Diagnostic] WebSocket URL: $wsUrl');
        }
      }
      
      final httpOk = await testHttpConnection();
      print('[Diagnostic] HTTP Connectivity: ${httpOk ? 'OK ✓' : 'FAILED ✗'}');
      print('[Diagnostic] ==================================');
    } catch (e) {
      print('[Diagnostic] Error logging network info: $e');
    }
  }
}
