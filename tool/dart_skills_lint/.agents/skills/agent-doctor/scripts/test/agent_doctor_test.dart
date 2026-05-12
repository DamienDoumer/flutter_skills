// ignore_for_file: specify_nonobvious_local_variable_types, omit_obvious_local_variable_types

import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import '../agent_doctor.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('agent_doctor_test.');
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('findLockFiles finds lock files in subdirectory', () {
    final toolDir = Directory(p.join(tempDir.path, 'tool', 'linter'))..createSync(recursive: true);
    final lockFile = File(p.join(toolDir.path, 'skills-lock.json'))..writeAsStringSync('{}');
    
    final found = findLockFiles(tempDir);
    expect(found, hasLength(1));
    expect(found.first.path, lockFile.path);
  });

  test('checkMissingSkills detects missing folder', () {
    final lockFile = File(p.join(tempDir.path, 'skills-lock.json'));
    lockFile.writeAsStringSync('''
    {
      "version": 1,
      "skills": {
        "dart-best-practices": {
          "source": "kevmoo/dash_skills"
        },
        "definition-of-done": {
          "source": "local"
        }
      }
    }
    ''');
    
    Directory(p.join(tempDir.path, '.agents', 'skills', 'definition-of-done')).createSync(recursive: true);
    
    final missing = checkMissingSkills(lockFile);
    expect(missing, contains('dart-best-practices'));
    expect(missing, isNot(contains('definition-of-done')));
  });

  test('checkMissingSkills returns empty list when all folders exist', () {
    final lockFile = File(p.join(tempDir.path, 'skills-lock.json'));
    lockFile.writeAsStringSync('''
    {
      "skills": {
        "test-skill": {
          "source": "remote"
        }
      }
    }
    ''');
    
    Directory(p.join(tempDir.path, '.agents', 'skills', 'test-skill')).createSync(recursive: true);
    
    final missing = checkMissingSkills(lockFile);
    expect(missing, isEmpty);
  });

  group('JSON parsing unit tests', () {
    test('checkMissingSkills catches FormatException with invalid json syntax', () {
      final lockFile = File(p.join(tempDir.path, 'skills-lock.json'));
      lockFile.writeAsStringSync('{ invalid json: format ');
      
      final missing = checkMissingSkills(lockFile);
      expect(missing, isEmpty);
    });

    test('checkMissingSkills handles missing skills key gracefully', () {
      final lockFile = File(p.join(tempDir.path, 'skills-lock.json'));
      lockFile.writeAsStringSync('{"version": 1}');
      
      final missing = checkMissingSkills(lockFile);
      expect(missing, isEmpty);
    });

    test('checkMissingSkills handles empty skills map', () {
      final lockFile = File(p.join(tempDir.path, 'skills-lock.json'));
      lockFile.writeAsStringSync('{"version": 1, "skills": {}}');
      
      final missing = checkMissingSkills(lockFile);
      expect(missing, isEmpty);
    });
  });
}
