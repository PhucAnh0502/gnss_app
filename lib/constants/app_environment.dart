class AppEnvironment {
  static const String mode = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'dev',
  );

  static const bool isProduction = mode == 'prod';
  static const bool isDevelopment = !isProduction;

  static const String envFileName = isProduction ? '.env.prod' : '.env.dev';
}