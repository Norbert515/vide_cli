import 'package:nocterm/nocterm.dart';

/// A scope that was previously used for hook setup.
/// Now that we use control protocol callbacks, no setup is required.
/// This class maintains the original timing by deferring the child by one frame
/// to avoid exposing a nocterm overlay disposal bug.
class SetupScope extends StatefulComponent {
  final Component child;

  const SetupScope({required this.child, super.key});

  @override
  State<SetupScope> createState() => _SetupScopeState();
}

class _SetupScopeState extends State<SetupScope> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    // Defer showing child by one frame to maintain original timing
    Future.microtask(() {
      if (mounted) {
        setState(() => _ready = true);
      }
    });
  }

  @override
  Component build(BuildContext context) {
    if (!_ready) {
      return SizedBox();
    }
    return component.child;
  }
}
