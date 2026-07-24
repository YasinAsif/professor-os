/// ProfessorOS – API constants.

class ApiConstants {
  ApiConstants._();

  // Override for Android/web deployments with:
  // --dart-define=API_BASE_URL=https://your-api.example.com/api/v1
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://professor-os-production.up.railway.app/api/v1',
  );

  // Auth
  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String refresh = '/auth/refresh';
  static const String logout = '/auth/logout';
  static const String verifyEmail = '/auth/verify-email';
  static const String resendVerification = '/auth/resend-verification';
  static const String forgotPassword = '/auth/forgot-password';
  static const String resetPassword = '/auth/reset-password';

  // Users
  static const String me = '/users/me';
  static const String changePassword = '/users/me/password';
  static const String signOutAll = '/users/me/sessions';
  static const String adminUsers = '/admin/users';
  static const String adminImport = '/admin/users/import';
  static String adminUserStatus(int id) => '/admin/users/$id/status';
  static String adminUserDelete(int id) => '/admin/users/$id';

  // Courses
  static const String courses = '/courses';
  static String course(int id) => '/courses/$id';
  static String courseEnroll(int id) => '/courses/$id/enroll';
  static String courseEnrollments(int id) => '/courses/$id/enrollments';
  static String courseEnrollCsv(int id) => '/courses/$id/enroll/csv';
  static String courseClos(int id) => '/courses/$id/clos';
  static String courseAssignments(int id) => '/courses/$id/assignments';
  static String courseAnalytics(int id) => '/courses/$id/analytics';

  // Assignments
  static String assignment(int courseId, int aid) =>
      '/courses/$courseId/assignments/$aid';
  static String publishAssignment(int courseId, int aid) =>
      '/courses/$courseId/assignments/$aid/publish';
  static String rubric(int aid) => '/assignments/$aid/rubric';
}
