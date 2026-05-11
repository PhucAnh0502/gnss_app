import 'dart:convert';

class JwtUtils {
  static bool isExpired(String token) {
    try {
      final payload = _decodePayload(token);
      final exp = payload['exp'];
      if (exp is! num || !exp.isFinite) {
        return true;
      }

      final expiry = DateTime.fromMillisecondsSinceEpoch(exp.toInt() * 1000);
      return !expiry.isAfter(DateTime.now());
    } catch (_) {
      return true;
    }
  }

  static Map<String, dynamic> _decodePayload(String token) {
    final parts = token.split('.');
    if (parts.length != 3) {
      throw const FormatException('Invalid JWT structure');
    }

    final payload = base64Url.normalize(parts[1]);
    final payloadMap = jsonDecode(utf8.decode(base64Url.decode(payload)));
    if (payloadMap is! Map<String, dynamic>) {
      throw const FormatException('Invalid JWT payload');
    }

    return payloadMap;
  }
}
