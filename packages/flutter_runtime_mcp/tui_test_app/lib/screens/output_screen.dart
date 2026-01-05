import 'dart:async';
import 'package:nocterm/nocterm.dart';
import 'package:flutter_runtime_mcp/flutter_runtime_mcp.dart';

/// Screen showing real-time output from a Flutter instance
class OutputScreen extends StatefulComponent {
  final FlutterRuntimeServer server;
  final FlutterInstance instance;

  const OutputScreen({required this.server, required this.instance, super.key});

  @override
  State<OutputScreen> createState() => _OutputScreenState();
}

class _OutputScreenState extends State<OutputScreen> {
  final AutoScrollController _scrollController = AutoScrollController();
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    // Refresh output every second
    _refreshTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Component build(BuildContext context) {
    final screenComponent = context.component as OutputScreen;
    final instance = screenComponent.instance;

    return Focusable(
      focused: true,
      onKeyEvent: (event) {
        if (event.logicalKey == LogicalKey.keyB ||
            event.logicalKey == LogicalKey.escape) {
          Navigator.of(context).pop();
          return true;
        }
        return false;
      },
      child: Container(
        decoration: const BoxDecoration(color: Color.fromRGB(15, 15, 35)),
        child: Column(
          children: [
            _buildHeader(instance),
            Expanded(child: _buildOutput(instance)),
            if (instance.bufferedErrors.isNotEmpty)
              Expanded(flex: 1, child: _buildErrors(instance)),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Component _buildHeader(FlutterInstance instance) {
    return Container(
      padding: const EdgeInsets.all(1),
      decoration: BoxDecoration(
        color: const Color.fromRGB(30, 60, 120),
        border: BoxBorder.all(color: Colors.cyan, style: BoxBorderStyle.double),
      ),
      child: Column(
        children: [
          const Text(
            'Output Viewer',
            style: TextStyle(
              color: Colors.brightWhite,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            'Instance: ${_truncate(instance.id, 50)}',
            style: const TextStyle(color: Colors.gray),
          ),
        ],
      ),
    );
  }

  Component _buildOutput(FlutterInstance instance) {
    final outputLines = instance.bufferedOutput;

    return Container(
      decoration: BoxDecoration(
        color: const Color.fromRGB(10, 10, 25),
        border: BoxBorder.all(color: Colors.green),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 1),
            decoration: const BoxDecoration(color: Color.fromRGB(20, 40, 20)),
            child: Row(
              children: [
                const Text(
                  '📤 STDOUT',
                  style: TextStyle(
                    color: Colors.brightGreen,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  '${outputLines.length} lines',
                  style: const TextStyle(color: Colors.gray),
                ),
              ],
            ),
          ),
          Expanded(
            child: outputLines.isEmpty
                ? const Center(
                    child: Text(
                      'No output yet...',
                      style: TextStyle(
                        color: Colors.gray,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  )
                : Scrollbar(
                    controller: _scrollController,
                    thumbVisibility: true,
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(1),
                      itemCount: outputLines.length,
                      itemBuilder: (context, index) {
                        return Text(
                          outputLines[index],
                          style: const TextStyle(color: Colors.green),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Component _buildErrors(FlutterInstance instance) {
    final errorLines = instance.bufferedErrors;

    return Container(
      decoration: BoxDecoration(
        color: const Color.fromRGB(25, 10, 10),
        border: BoxBorder.all(color: Colors.red),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 1),
            decoration: const BoxDecoration(color: Color.fromRGB(40, 20, 20)),
            child: Row(
              children: [
                const Text(
                  '⚠️  STDERR',
                  style: TextStyle(
                    color: Colors.brightRed,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  '${errorLines.length} lines',
                  style: const TextStyle(color: Colors.gray),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(1),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: errorLines
                      .map(
                        (line) => Text(
                          line,
                          style: const TextStyle(color: Colors.red),
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Component _buildFooter() {
    return const Container(
      padding: EdgeInsets.all(1),
      decoration: BoxDecoration(
        color: Color.fromRGB(20, 20, 40),
        border: BoxBorder(top: BorderSide(color: Colors.blue)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Output updates automatically every second',
            style: TextStyle(color: Colors.gray, fontStyle: FontStyle.italic),
          ),
          Text('[B/Esc] Back', style: TextStyle(color: Colors.yellow)),
        ],
      ),
    );
  }

  String _truncate(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength - 3)}...';
  }
}
