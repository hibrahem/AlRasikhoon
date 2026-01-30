/// Main integration test entry point
/// Run all E2E tests with: flutter test integration_test/app_test.dart
library;

import 'admin_flow_test.dart' as admin_flow;
import 'teacher_flow_test.dart' as teacher_flow;
import 'student_flow_test.dart' as student_flow;
import 'supervisor_flow_test.dart' as supervisor_flow;

void main() {
  admin_flow.main();
  teacher_flow.main();
  student_flow.main();
  supervisor_flow.main();
}
