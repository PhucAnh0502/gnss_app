import 'package:flutter/material.dart';
import 'package:gnss_app/constants/app_colors.dart';
import 'package:gnss_app/constants/app_environment.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
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
  runApp(const ProviderScope(child: MyApp()));
}

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GNSS Tracker',
      debugShowCheckedModeBanner: false,
      navigatorKey: appNavigatorKey,
      scaffoldMessengerKey: AppSnackBar.messengerKey,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.primaryDark,
        primaryColor: AppColors.brandBlue,
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.bgInput,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: AppColors.slate400.withValues(alpha: 0.25),
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: AppColors.slate400.withValues(alpha: 0.25),
            ),
          ),
          focusedBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            borderSide: BorderSide(color: AppColors.brandBlue),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.brandBlue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
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
