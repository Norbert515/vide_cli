import 'package:nocterm/nocterm.dart';
import 'package:nocterm_riverpod/nocterm_riverpod.dart';
import 'package:vide_core/vide_core.dart'
    show
        AskUserQuestionData,
        AskUserQuestionOptionData,
        VideLogger;
import 'package:vide_cli/constants/text_opacity.dart';
import 'package:vide_cli/main.dart' show filePreviewPathProvider;
import 'package:vide_cli/modules/agent_network/state/vide_session_providers.dart';
import 'package:vide_cli/modules/permissions/permission_scope.dart';
import 'package:vide_cli/modules/permissions/permission_service.dart';
import 'package:vide_cli/modules/settings/components/settings_card.dart';
import 'package:vide_cli/theme/theme.dart';

/// Debug settings: session logs viewer, admin test triggers.
class DebugSettingsSection extends StatefulComponent {
  final bool focused;
  final VoidCallback onExit;

  const DebugSettingsSection({
    required this.focused,
    required this.onExit,
    super.key,
  });

  @override
  State<DebugSettingsSection> createState() => _DebugSettingsSectionState();
}

class _DebugSettingsSectionState extends State<DebugSettingsSection> {
  int _selectedIndex = 0;

  // [0] = Session logs,
  // [1] = Permission (short), [2] = Permission (long),
  // [3] = AskUserQuestion, [4] = Plan Approval
  static const int _totalItems = 5;

  bool _handleKeyEvent(KeyboardEvent event) {
    if (!component.focused) return false;

    if (event.logicalKey == LogicalKey.arrowUp ||
        event.logicalKey == LogicalKey.keyK) {
      if (_selectedIndex > 0) {
        setState(() => _selectedIndex--);
      }
      return true;
    } else if (event.logicalKey == LogicalKey.arrowDown ||
        event.logicalKey == LogicalKey.keyJ) {
      if (_selectedIndex < _totalItems - 1) {
        setState(() => _selectedIndex++);
      }
      return true;
    } else if (event.logicalKey == LogicalKey.arrowLeft ||
        event.logicalKey == LogicalKey.escape) {
      component.onExit();
      return true;
    } else if (event.logicalKey == LogicalKey.enter ||
        event.logicalKey == LogicalKey.space) {
      _activateCurrentItem();
      return true;
    }

    return false;
  }

  void _activateCurrentItem() {
    switch (_selectedIndex) {
      case 0:
        _openSessionLogs();
      case 1:
        _triggerShortPermission();
      case 2:
        _triggerLongPermission();
      case 3:
        _triggerAskUserQuestion();
      case 4:
        _triggerPlanApproval();
    }
  }

  void _openSessionLogs() {
    final session = context.read(currentVideSessionProvider);
    final sessionId = session?.id;
    if (sessionId == null) return;
    final logPath = VideLogger.instance.sessionLogPath(sessionId);
    context.read(filePreviewPathProvider.notifier).state = logPath;
  }

  void _triggerShortPermission() {
    context
        .read(permissionStateProvider.notifier)
        .enqueueRequest(
          PermissionRequest(
            requestId: 'test-short-${DateTime.now().millisecondsSinceEpoch}',
            toolName: 'Bash',
            toolInput: {'command': 'ls -la'},
            cwd: '/tmp',
            inferredPattern: 'Bash(ls *)',
          ),
        );
  }

  void _triggerLongPermission() {
    context
        .read(permissionStateProvider.notifier)
        .enqueueRequest(
          PermissionRequest(
            requestId: 'test-long-${DateTime.now().millisecondsSinceEpoch}',
            toolName: 'Bash',
            toolInput: {
              'command':
                  '#!/bin/bash\n'
                  'set -euo pipefail\n'
                  '\n'
                  '# ============================================================\n'
                  '# Flutter Project Health Check & Deployment Script\n'
                  '# ============================================================\n'
                  '\n'
                  'PROJECT_ROOT="\$(cd "\$(dirname "\$0")/.." && pwd)"\n'
                  'BUILD_DIR="\$PROJECT_ROOT/build"\n'
                  'COVERAGE_DIR="\$BUILD_DIR/coverage"\n'
                  'REPORT_FILE="\$BUILD_DIR/health_report.json"\n'
                  'MIN_COVERAGE=80\n'
                  'DART_SDK_VERSION="3.3.0"\n'
                  'FLUTTER_CHANNEL="stable"\n'
                  '\n'
                  'RED=\'\\033[0;31m\'\n'
                  'GREEN=\'\\033[0;32m\'\n'
                  'YELLOW=\'\\033[1;33m\'\n'
                  'NC=\'\\033[0m\'\n'
                  '\n'
                  'log_info() { echo -e "\${GREEN}[INFO]\${NC} \$1"; }\n'
                  'log_warn() { echo -e "\${YELLOW}[WARN]\${NC} \$1"; }\n'
                  'log_error() { echo -e "\${RED}[ERROR]\${NC} \$1"; }\n'
                  '\n'
                  '# --- Pre-flight checks ---\n'
                  'log_info "Running pre-flight checks..."\n'
                  '\n'
                  'if ! command -v flutter &> /dev/null; then\n'
                  '    log_error "Flutter not found in PATH"\n'
                  '    exit 1\n'
                  'fi\n'
                  '\n'
                  'if ! command -v dart &> /dev/null; then\n'
                  '    log_error "Dart SDK not found in PATH"\n'
                  '    exit 1\n'
                  'fi\n'
                  '\n'
                  'CURRENT_DART=\$(dart --version 2>&1 | grep -oP \'\\d+\\.\\d+\\.\\d+\')\n'
                  'log_info "Dart SDK version: \$CURRENT_DART (minimum: \$DART_SDK_VERSION)"\n'
                  '\n'
                  '# --- Clean previous build artifacts ---\n'
                  'log_info "Cleaning previous build artifacts..."\n'
                  'rm -rf "\$BUILD_DIR"\n'
                  'mkdir -p "\$COVERAGE_DIR"\n'
                  'flutter clean\n'
                  'dart pub get\n'
                  '\n'
                  '# --- Static analysis ---\n'
                  'log_info "Running static analysis..."\n'
                  'ANALYZE_OUTPUT=\$(dart analyze --fatal-infos 2>&1) || {\n'
                  '    log_error "Static analysis failed:"\n'
                  '    echo "\$ANALYZE_OUTPUT"\n'
                  '    exit 1\n'
                  '}\n'
                  'log_info "Static analysis passed"\n'
                  '\n'
                  '# --- Format check ---\n'
                  'log_info "Checking code formatting..."\n'
                  'UNFORMATTED=\$(dart format --set-exit-if-changed --output=none . 2>&1) || {\n'
                  '    log_error "Code formatting issues found:"\n'
                  '    echo "\$UNFORMATTED"\n'
                  '    exit 1\n'
                  '}\n'
                  'log_info "Code formatting OK"\n'
                  '\n'
                  '# --- Run tests with coverage ---\n'
                  'log_info "Running tests with coverage..."\n'
                  'flutter test --coverage --coverage-path="\$COVERAGE_DIR/lcov.info" \\\n'
                  '    --reporter=json > "\$BUILD_DIR/test_results.json" 2>&1 || {\n'
                  '    log_error "Tests failed! See \$BUILD_DIR/test_results.json"\n'
                  '    exit 1\n'
                  '}\n'
                  '\n'
                  'TOTAL_TESTS=\$(cat "\$BUILD_DIR/test_results.json" | grep -c \'"result":"success"\')\n'
                  'log_info "All \$TOTAL_TESTS tests passed"\n'
                  '\n'
                  '# --- Coverage analysis ---\n'
                  'log_info "Analyzing code coverage..."\n'
                  'if command -v lcov &> /dev/null; then\n'
                  '    lcov --summary "\$COVERAGE_DIR/lcov.info" 2>&1 | tee "\$COVERAGE_DIR/summary.txt"\n'
                  '    COVERAGE=\$(grep -oP \'lines\\.+:\\s+\\K[\\d.]+\' "\$COVERAGE_DIR/summary.txt")\n'
                  '    if (( \$(echo "\$COVERAGE < \$MIN_COVERAGE" | bc -l) )); then\n'
                  '        log_warn "Coverage \${COVERAGE}% is below minimum \${MIN_COVERAGE}%"\n'
                  '    else\n'
                  '        log_info "Coverage: \${COVERAGE}% (minimum: \${MIN_COVERAGE}%)"\n'
                  '    fi\n'
                  '    genhtml "\$COVERAGE_DIR/lcov.info" -o "\$COVERAGE_DIR/html" --quiet\n'
                  'else\n'
                  '    log_warn "lcov not installed, skipping coverage report"\n'
                  'fi\n'
                  '\n'
                  '# --- Build release artifacts ---\n'
                  'log_info "Building release artifacts..."\n'
                  'for platform in "web" "apk" "ios"; do\n'
                  '    log_info "  Building \$platform..."\n'
                  '    case \$platform in\n'
                  '        web)\n'
                  '            flutter build web --release --tree-shake-icons \\\n'
                  '                --dart-define=ENV=production 2>&1 | tail -5\n'
                  '            ;;\n'
                  '        apk)\n'
                  '            flutter build apk --release --split-per-abi \\\n'
                  '                --dart-define=ENV=production 2>&1 | tail -5\n'
                  '            ;;\n'
                  '        ios)\n'
                  '            flutter build ios --release --no-codesign \\\n'
                  '                --dart-define=ENV=production 2>&1 | tail -5\n'
                  '            ;;\n'
                  '    esac\n'
                  'done\n'
                  '\n'
                  '# --- Generate health report ---\n'
                  'log_info "Generating health report..."\n'
                  'cat > "\$REPORT_FILE" << EOF\n'
                  '{\n'
                  '  "timestamp": "\$(date -u +%Y-%m-%dT%H:%M:%SZ)",\n'
                  '  "dart_version": "\$CURRENT_DART",\n'
                  '  "flutter_channel": "\$FLUTTER_CHANNEL",\n'
                  '  "analysis": "passed",\n'
                  '  "formatting": "passed",\n'
                  '  "tests_total": \$TOTAL_TESTS,\n'
                  '  "tests_passed": \$TOTAL_TESTS,\n'
                  '  "coverage_percent": \${COVERAGE:-"unknown"},\n'
                  '  "builds": ["web", "apk", "ios"]\n'
                  '}\n'
                  'EOF\n'
                  '\n'
                  'log_info "Health report saved to \$REPORT_FILE"\n'
                  'log_info "All checks passed successfully!"',
            },
            cwd: '/Users/dev/my-flutter-app',
            inferredPattern: 'Bash(#!/bin/bash*)',
          ),
        );
  }

  void _triggerAskUserQuestion() {
    context
        .read(askUserQuestionStateProvider.notifier)
        .enqueueRequest(
          AskUserQuestionUIRequest(
            requestId: 'test-ask-${DateTime.now().millisecondsSinceEpoch}',
            questions: [
              AskUserQuestionData(
                question: 'Which database should we use for the new feature?',
                header: 'Database',
                options: [
                  AskUserQuestionOptionData(
                    label: 'PostgreSQL',
                    description: 'Relational DB with strong ACID compliance',
                  ),
                  AskUserQuestionOptionData(
                    label: 'SQLite',
                    description:
                        'Lightweight embedded database, no server needed',
                  ),
                  AskUserQuestionOptionData(
                    label: 'Redis',
                    description: 'In-memory key-value store, very fast reads',
                  ),
                ],
              ),
            ],
          ),
        );
  }

  void _triggerPlanApproval() {
    context
        .read(planApprovalStateProvider.notifier)
        .enqueueRequest(
          PlanApprovalUIRequest(
            requestId: 'test-plan-${DateTime.now().millisecondsSinceEpoch}',
            planContent: '''# Implementation Plan: User Authentication

## Context
Adding JWT-based authentication to the REST API.

## Steps

1. **Create auth middleware** (`lib/middleware/auth.dart`)
   - Validate JWT tokens from Authorization header
   - Extract user ID and attach to request context

2. **Add login endpoint** (`lib/routes/auth.dart`)
   - POST /api/v1/auth/login
   - Accept email + password, return JWT + refresh token

3. **Add token refresh** (`lib/routes/auth.dart`)
   - POST /api/v1/auth/refresh
   - Accept refresh token, return new JWT

## Files Changed
- `lib/middleware/auth.dart` (new)
- `lib/routes/auth.dart` (new)
- `lib/routes/api_routes.dart` (modified)
- `test/auth_test.dart` (new)

## Verification
- Unit tests for token validation
- Integration tests for login/refresh flow
''',
          ),
        );
  }

  @override
  Component build(BuildContext context) {
    final session = context.watch(currentVideSessionProvider);
    final sessionId = session?.id;
    final logPath = sessionId != null
        ? VideLogger.instance.sessionLogPath(sessionId)
        : null;

    return Focusable(
      focused: component.focused,
      onKeyEvent: _handleKeyEvent,
      child: Padding(
        padding: EdgeInsets.only(top: 1),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SettingsCard(
              title: 'Debug',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ActionItem(
                    label: 'Session Logs',
                    description: logPath ?? 'No active session',
                    isSelected: component.focused && _selectedIndex == 0,
                    onTap: () {
                      setState(() => _selectedIndex = 0);
                      _openSessionLogs();
                    },
                  ),
                ],
              ),
            ),
            SizedBox(height: 1),
            SettingsCard(
              title: 'Admin',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ActionItem(
                    label: 'Permission (short)',
                    description: 'Trigger a short permission dialog',
                    isSelected: component.focused && _selectedIndex == 1,
                    onTap: () {
                      setState(() => _selectedIndex = 1);
                      _triggerShortPermission();
                    },
                  ),
                  _ActionItem(
                    label: 'Permission (long)',
                    description: 'Trigger a long permission dialog',
                    isSelected: component.focused && _selectedIndex == 2,
                    onTap: () {
                      setState(() => _selectedIndex = 2);
                      _triggerLongPermission();
                    },
                  ),
                  _ActionItem(
                    label: 'AskUserQuestion',
                    description: 'Trigger an ask-user-question dialog',
                    isSelected: component.focused && _selectedIndex == 3,
                    onTap: () {
                      setState(() => _selectedIndex = 3);
                      _triggerAskUserQuestion();
                    },
                  ),
                  _ActionItem(
                    label: 'Plan Approval',
                    description: 'Trigger a plan approval dialog',
                    isSelected: component.focused && _selectedIndex == 4,
                    onTap: () {
                      setState(() => _selectedIndex = 4);
                      _triggerPlanApproval();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionItem extends StatelessComponent {
  final String label;
  final String description;
  final bool isSelected;
  final VoidCallback onTap;

  const _ActionItem({
    required this.label,
    required this.description,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Component build(BuildContext context) {
    final theme = VideTheme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 1, vertical: 1),
        decoration: BoxDecoration(
          color: isSelected ? theme.base.primary.withOpacity(0.2) : null,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: theme.base.onSurface,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    description,
                    style: TextStyle(
                      color: theme.base.onSurface.withOpacity(
                        TextOpacity.secondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '\u2192',
              style: TextStyle(
                color: isSelected ? theme.base.primary : theme.base.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
