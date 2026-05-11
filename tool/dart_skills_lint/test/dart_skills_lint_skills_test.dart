import 'dart:async';
import 'dart:io';
import 'package:dart_skills_lint/dart_skills_lint.dart';
import 'package:logging/logging.dart';
import 'package:test/test.dart';

void main() {
  test('Run skills linter', () async {
    final Level oldLevel = Logger.root.level;
    Logger.root.level = Level.ALL;
    final StreamSubscription<LogRecord> subscription = Logger.root.onRecord.listen(
      (record) => stdout.writeln(record.message),
    );

    try {
      final bool isValid = await validateSkills(
        skillDirPaths: ['.agents/skills', 'skills', '../../skills'],
        resolvedRules: {
          'check-relative-paths': AnalysisSeverity.error,
          'check-trailing-whitespace': AnalysisSeverity.error,
        },
      );
      expect(isValid, isTrue, reason: 'Skills validation failed. See above for details.');
    } finally {
      Logger.root.level = oldLevel;
      await subscription.cancel();
    }
  });
}
