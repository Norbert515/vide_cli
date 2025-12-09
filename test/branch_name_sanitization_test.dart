import 'package:test/test.dart';

/// Test the branch name sanitization logic
String sanitizeBranchName(String description) {
  // Convert to lowercase, replace spaces and special chars with hyphens
  var name = description
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'-+'), '-') // Replace multiple hyphens with single
      .replaceAll(RegExp(r'^-|-$'), ''); // Remove leading/trailing hyphens

  // Limit to 50 characters
  if (name.length > 50) {
    name = name.substring(0, 50).replaceAll(RegExp(r'-$'), '');
  }

  return name;
}

void main() {
  group('Branch name sanitization', () {
    test('converts to lowercase and replaces spaces with hyphens', () {
      expect(
        sanitizeBranchName('Add User Authentication'),
        'add-user-authentication',
      );
    });

    test('replaces special characters with hyphens', () {
      expect(
        sanitizeBranchName('Fix: bug with @user/profile'),
        'fix-bug-with-user-profile',
      );
    });

    test('removes consecutive hyphens', () {
      expect(
        sanitizeBranchName('Add   multiple   spaces'),
        'add-multiple-spaces',
      );
    });

    test('removes leading and trailing hyphens', () {
      expect(sanitizeBranchName('  Add feature  '), 'add-feature');
    });

    test('truncates to 50 characters', () {
      final longName =
          'This is a very long task description that exceeds fifty characters';
      final result = sanitizeBranchName(longName);
      expect(result.length, lessThanOrEqualTo(50));
      expect(result, 'this-is-a-very-long-task-description-that-exceeds');
    });

    test('removes trailing hyphen after truncation', () {
      final longName =
          'This is a very long task description that has a hyphen at';
      final result = sanitizeBranchName(longName);
      expect(result.endsWith('-'), isFalse);
    });

    test('handles emoji and unicode characters', () {
      expect(sanitizeBranchName('Add 🚀 rocket feature'), 'add-rocket-feature');
    });
  });
}
