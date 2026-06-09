import 'package:yaml/yaml.dart';
import '../models/analysis_severity.dart';
import '../models/skill_context.dart';
import '../models/skill_rule.dart';
import '../models/validation_error.dart';

/// Enforces that 'metadata: internal: true' is present in YAML metadata.
class PreventSkillsShPublishingRule extends SkillRule {
  PreventSkillsShPublishingRule({this.severity = defaultSeverity});

  static const String ruleName = 'prevent-skills-sh-publishing';
  static const AnalysisSeverity defaultSeverity = AnalysisSeverity.disabled;

  @override
  String get name => ruleName;

  @override
  final AnalysisSeverity severity;

  static const _skillFileName = 'SKILL.md';

  @override
  Future<List<ValidationError>> validate(SkillContext context) async {
    final errors = <ValidationError>[];

    if (context.parsedYaml == null) {
      errors.add(
        ValidationError(
          ruleId: name,
          severity: severity,
          file: _skillFileName,
          message: 'Missing YAML frontmatter, expected metadata: internal: true.',
        ),
      );
      return errors;
    }

    final YamlMap yaml = context.parsedYaml!;
    final Object? metadata = yaml['metadata'];

    var isInternalTrue = false;
    if (metadata is YamlMap) {
      if (metadata['internal'] == true) {
        isInternalTrue = true;
      }
    }

    if (!isInternalTrue) {
      errors.add(
        ValidationError(
          ruleId: name,
          severity: severity,
          file: _skillFileName,
          message: 'Skill is missing metadata: internal: true in frontmatter.',
        ),
      );
    }

    return errors;
  }
}
