class FormValidators {
  static String? requiredField(String? value, {required String label}) {
    if (value == null || value.trim().isEmpty) {
      return '$label is required';
    }
    return null;
  }

  static String? email(String? value) {
    final required = requiredField(value, label: 'Email');
    if (required != null) {
      return required;
    }

    final input = value!.trim();
    final regex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    if (!regex.hasMatch(input)) {
      return 'Invalid email format';
    }

    return null;
  }

  static String? username(String? value) {
    final required = requiredField(value, label: 'Username');
    if (required != null) {
      return required;
    }

    final input = value!.trim();
    if (input.length < 6) {
      return 'Username must be at least 6 characters';
    }

    return null;
  }

  static String? password(String? value, {String label = 'Password'}) {
    final required = requiredField(value, label: label);
    if (required != null) {
      return required;
    }

    final input = value!;
    if (input.length < 6) {
      return '$label must be at least 6 characters';
    }
    if (!RegExp(r'\d').hasMatch(input)) {
      return '$label must include at least 1 number';
    }
    if (!RegExp(r'[!@#$%^&*]').hasMatch(input)) {
      return '$label must include at least 1 special character (!@#\$%^&*)';
    }

    return null;
  }

  static String? confirmPassword(String? value, {required String password}) {
    final required = requiredField(value, label: 'Confirm password');
    if (required != null) {
      return required;
    }

    if (value != password) {
      return 'Password confirmation does not match';
    }

    return null;
  }

  static String? otpCode(String? value) {
    final required = requiredField(value, label: 'OTP');
    if (required != null) {
      return required;
    }

    if (!RegExp(r'^\d{6}$').hasMatch(value!.trim())) {
      return 'OTP must be 6 digits';
    }

    return null;
  }
}
