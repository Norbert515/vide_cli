import 'package:nocterm/nocterm.dart';
import 'package:parott/modules/mcp/git/git_client.dart';
import 'package:parott/constants/text_opacity.dart';

class GitBranchIndicator extends StatefulComponent {
  final String sessionId;

  const GitBranchIndicator({required this.sessionId, super.key});

  @override
  State<GitBranchIndicator> createState() => _GitBranchIndicatorState();
}

class _GitBranchIndicatorState extends State<GitBranchIndicator> {
  String? _currentBranch;
  bool _isLoading = true;
  DateTime? _lastFetch;

  @override
  void initState() {
    super.initState();
    _loadGitStatus();
  }

  Future<void> _loadGitStatus() async {
    // Check cache (5 second TTL)
    if (_lastFetch != null &&
        DateTime.now().difference(_lastFetch!) < Duration(seconds: 5)) {
      return;
    }

    try {
      final git = GitClient();
      final branch = await git.currentBranch();

      if (branch.isNotEmpty) {
        setState(() {
          _currentBranch = branch;
          _isLoading = false;
          _lastFetch = DateTime.now();
        });
        return;
      }
    } catch (e) {
      // Silently fail - not in a git repo or git not available
    }

    setState(() {
      _isLoading = false;
      _lastFetch = DateTime.now();
    });
  }

  @override
  Component build(BuildContext context) {
    if (_isLoading || _currentBranch == null) {
      return SizedBox();
    }

    return Text(
      '[git: $_currentBranch]',
      style: TextStyle(color: Colors.white.withOpacity(TextOpacity.secondary)),
    );
  }
}
