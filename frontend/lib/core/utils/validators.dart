/// ProfessorOS – Form validators.

class Validators {
  Validators._();

  static String? email(String? value) {
    if (value == null || value.isEmpty) return 'Email is required.';
    final regex = RegExp(r'^[\w\.\-]+@[\w\.\-]+\.\w{2,}$');
    if (!regex.hasMatch(value)) return 'Enter a valid email address.';
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) return 'Password is required.';
    if (value.length < 8) return 'Password must be at least 8 characters.';
    return null;
  }

  static String? required(String? value, [String field = 'This field']) {
    if (value == null || value.trim().isEmpty) return '$field is required.';
    return null;
  }

  /// Password strength (0-4): Weak / Fair / Strong / Very Strong
  static int passwordStrength(String password) {
    int score = 0;
    if (password.length >= 8) score++;
    if (password.length >= 12) score++;
    if (RegExp(r'[A-Z]').hasMatch(password) && RegExp(r'[a-z]').hasMatch(password)) score++;
    if (RegExp(r'[0-9]').hasMatch(password)) score++;
    if (RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password)) score++;
    return score.clamp(0, 4);
  }

  static String strengthLabel(int score) {
    switch (score) {
      case 0:
        return 'Weak';
      case 1:
        return 'Fair';
      case 2:
        return 'Strong';
      case 3:
      case 4:
        return 'Very Strong';
      default:
        return '';
    }
  }
}
