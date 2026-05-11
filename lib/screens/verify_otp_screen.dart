import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gnss_app/providers/auth_provider.dart';
import 'package:gnss_app/screens/reset_password_screen.dart';
import 'package:gnss_app/utils/app_snackbar.dart';
import 'package:gnss_app/utils/form_validators.dart';
import 'package:gnss_app/widgets/auth_scaffold.dart';

class VerifyOtpScreen extends ConsumerStatefulWidget {
  const VerifyOtpScreen({super.key, this.initialEmail});

  static const routeName = '/verify-otp';

  final String? initialEmail;

  @override
  ConsumerState<VerifyOtpScreen> createState() => _VerifyOtpScreenState();
}

class _VerifyOtpScreenState extends ConsumerState<VerifyOtpScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailCtrl;
  final _otpCtrls = List.generate(6, (_) => TextEditingController());
  final _otpFocusNodes = List.generate(6, (_) => FocusNode());
  String? _otpError;

  String get _otpValue => _otpCtrls.map((controller) => controller.text).join();

  @override
  void initState() {
    super.initState();
    _emailCtrl = TextEditingController(text: widget.initialEmail ?? '');
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    for (final controller in _otpCtrls) {
      controller.dispose();
    }
    for (final node in _otpFocusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    ref.listen<AuthState>(authProvider, (previous, next) {
      if (previous?.isLoading == true &&
          next.isLoading == false &&
          next.errorMessage == null) {
        AppSnackBar.success(context, 'OTP verified successfully.');
        Navigator.of(context).pushNamed(
          ResetPasswordScreen.routeName,
          arguments: {'email': _emailCtrl.text.trim(), 'otp': _otpValue},
        );
      }

      if (next.errorMessage != null &&
          next.errorMessage != previous?.errorMessage) {
        AppSnackBar.error(context, next.errorMessage!);
      }
    });

    return AuthScaffold(
      title: 'Verify OTP',
      subtitle: 'Enter the OTP code sent to your email',
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            TextFormField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email'),
              validator: FormValidators.email,
            ),
            const SizedBox(height: 12),
            _buildOtpInput(),
            if (_otpError != null) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _otpError!,
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              ),
            ],
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: authState.isLoading
                    ? null
                    : () async {
                        final isFormValid = _formKey.currentState!.validate();
                        final otpValidation = FormValidators.otpCode(_otpValue);

                        setState(() {
                          _otpError = otpValidation;
                        });

                        if (!isFormValid || otpValidation != null) {
                          return;
                        }
                        await ref
                            .read(authProvider.notifier)
                            .verifyResetOtp(
                              email: _emailCtrl.text.trim(),
                              otp: _otpValue,
                            );
                      },
                child: authState.isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Verify OTP'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOtpInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Align(alignment: Alignment.centerLeft, child: Text('OTP code')),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(6, (index) {
            return SizedBox(
              width: 46,
              child: TextField(
                controller: _otpCtrls[index],
                focusNode: _otpFocusNodes[index],
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 1,
                decoration: const InputDecoration(counterText: ''),
                onChanged: (value) {
                  final digit = value.replaceAll(RegExp(r'[^0-9]'), '');
                  if (digit != value) {
                    _otpCtrls[index].text = digit;
                    _otpCtrls[index].selection = TextSelection.fromPosition(
                      TextPosition(offset: _otpCtrls[index].text.length),
                    );
                  }

                  if (_otpError != null) {
                    setState(() {
                      _otpError = null;
                    });
                  }

                  if (digit.isNotEmpty && index < 5) {
                    _otpFocusNodes[index + 1].requestFocus();
                  }

                  if (digit.isEmpty && index > 0) {
                    _otpFocusNodes[index - 1].requestFocus();
                  }
                },
              ),
            );
          }),
        ),
      ],
    );
  }
}
