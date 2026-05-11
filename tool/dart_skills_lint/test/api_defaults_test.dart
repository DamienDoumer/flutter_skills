// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';
import 'package:dart_skills_lint/dart_skills_lint.dart';
import 'package:test/test.dart';

void main() {
  test('validateSkills applies default rules when not specified', () async {
    final Directory tempDir = await Directory.systemTemp.createTemp('api_test.');
    try {
      final Directory skillDir = await Directory('${tempDir.path}/test-skill').create();

      // Create a skill with invalid YAML metadata (missing frontmatter)
      // valid-yaml-metadata is error by default.
      await File('${skillDir.path}/SKILL.md').writeAsString('Invalid YAML No Frontmatter');

      // Call validateSkills with empty overrides.
      // It should apply default rules, including valid-yaml-metadata.
      final bool isValid = await validateSkills(individualSkillPaths: [skillDir.path]);

      expect(isValid, isFalse, reason: 'Should fail due to default rule valid-yaml-metadata.');
    } finally {
      await tempDir.delete(recursive: true);
    }
  });

  test('Validator skips disabled rules', () async {
    final Directory tempDir = await Directory.systemTemp.createTemp('api_test.');
    try {
      final Directory skillDir = await Directory('${tempDir.path}/test-skill').create();

      // Create a skill with invalid YAML metadata (missing frontmatter)
      await File('${skillDir.path}/SKILL.md').writeAsString('Invalid YAML No Frontmatter');

      // Create validator with the rule disabled.
      final validator = Validator(
        ruleOverrides: {'valid-yaml-metadata': AnalysisSeverity.disabled},
      );
      final ValidationResult result = await validator.validate(skillDir);

      final bool hasYamlError = result.validationErrors.any(
        (e) => e.ruleId == 'valid-yaml-metadata',
      );
      expect(
        hasYamlError,
        isFalse,
        reason: 'Should not have valid-yaml-metadata error when disabled.',
      );
    } finally {
      await tempDir.delete(recursive: true);
    }
  });
}
