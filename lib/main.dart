import 'package:flutter/material.dart';
import 'package:gnss_app/constants/app_colors.dart';
import 'package:gnss_app/constants/app_environment.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:gnss_app/services/tracking_background_service.dart';
import 'package:gnss_app/screens/change_password_screen.dart';
import 'package:gnss_app/screens/dashboard_screen.dart';
import 'package:gnss_app/screens/forgot_password_screen.dart';
import 'package:gnss_app/screens/login_screen.dart';
import 'package:gnss_app/screens/register_screen.dart';
import 'package:gnss_app/screens/reset_password_screen.dart';
import 'package:gnss_app/screens/verify_otp_screen.dart';
import 'package:gnss_app/utils/app_snackbar.dart';
import 'package:gnss_app/widgets/protected_route.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: AppEnvironment.envFileName);
  await TrackingBackgroundService.initialize();
  runApp(const ProviderScope(child: MyApp()));
}

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GNSS Vison',
      debugShowCheckedModeBanner: false,
      navigatorKey: appNavigatorKey,
      scaffoldMessengerKey: AppSnackBar.messengerKey,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.primaryDark,
        primaryColor: AppColors.brandBlue,
        useMaterial3: true,
        fontFamily: 'Inter',
        // ===== COLOR SCHEME =====
        colorScheme: const ColorScheme.dark(
          primary: AppColors.brandBlue,
          secondary: AppColors.purple,
          error: AppColors.error,
          surface: AppColors.bgCard,
          onSurface: AppColors.textLight,
        ),
        // ===== INPUT DECORATION =====
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.bgInput,
          contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          labelStyle: const TextStyle(color: AppColors.slate400, fontSize: 14),
          hintStyle: const TextStyle(color: AppColors.slate500, fontSize: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
              color: AppColors.slate700.withValues(alpha: 0.5),
              width: 1,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
              color: AppColors.slate700.withValues(alpha: 0.5),
              width: 1,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(
              color: AppColors.brandBlue,
              width: 1.5,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(
              color: AppColors.error,
              width: 1,
            ),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(
              color: AppColors.error,
              width: 1.5,
            ),
          ),
        ),
        // ===== FILLED BUTTON THEME =====
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.brandBlue,
            foregroundColor: AppColors.white,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            elevation: 0,
            textStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        // ===== TEXT BUTTON THEME =====
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: AppColors.brandBlue,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            textStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        // ===== OUTLINED BUTTON THEME =====
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.brandBlue,
            side: const BorderSide(
              color: AppColors.brandBlue,
              width: 1.5,
            ),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        // ===== CARD THEME =====
        cardTheme: CardThemeData(
          color: AppColors.bgCard,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(
              color: AppColors.slate700.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          margin: EdgeInsets.zero,
        ),
        // ===== DIALOG THEME =====
        dialogTheme: DialogThemeData(
          backgroundColor: const Color(0xFF16243A),
          elevation: 24,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: AppColors.slate700.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
        ),
        // ===== SNACK BAR THEME =====
        snackBarTheme: SnackBarThemeData(
          backgroundColor: AppColors.bgElevated,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 8,
          behavior: SnackBarBehavior.floating,
        ),
        // ===== APP BAR THEME =====
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: AppColors.textLight,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        // ===== DIVIDER THEME =====
        dividerTheme: DividerThemeData(
          color: AppColors.slate700.withValues(alpha: 0.4),
          thickness: 1,
          space: 16,
        ),
        // ===== SWITCH THEME =====
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return AppColors.white;
            }
            return AppColors.slate400;
          }),
          trackColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return AppColors.brandBlue;
            }
            return AppColors.slate700;
          }),
        ),
      ),
      initialRoute: LoginScreen.routeName,
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case LoginScreen.routeName:
            return MaterialPageRoute(builder: (_) => const LoginScreen());
          case RegisterScreen.routeName:
            return MaterialPageRoute(builder: (_) => const RegisterScreen());
          case ForgotPasswordScreen.routeName:
            return MaterialPageRoute(
              builder: (_) => const ForgotPasswordScreen(),
            );
          case VerifyOtpScreen.routeName:
            final email = settings.arguments is String
                ? settings.arguments as String
                : null;
            return MaterialPageRoute(
              builder: (_) => VerifyOtpScreen(initialEmail: email),
            );
          case ResetPasswordScreen.routeName:
            final args = settings.arguments;
            final email = args is Map<String, dynamic>
                ? args['email']?.toString()
                : null;
            final otp = args is Map<String, dynamic>
                ? args['otp']?.toString()
                : null;
            if (email == null || otp == null) {
              return MaterialPageRoute(builder: (_) => const VerifyOtpScreen());
            }
            return MaterialPageRoute(
              builder: (_) =>
                  ResetPasswordScreen(initialEmail: email, verifiedOtp: otp),
            );
          case DashboardScreen.routeName:
            return MaterialPageRoute(
              builder: (_) => const ProtectedRoute(child: DashboardScreen()),
            );
          case ChangePasswordScreen.routeName:
            return MaterialPageRoute(
              builder: (_) =>
                  const ProtectedRoute(child: ChangePasswordScreen()),
            );
          default:
            return MaterialPageRoute(builder: (_) => const LoginScreen());
        }
      },
    );
  }
}
