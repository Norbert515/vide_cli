import 'package:nocterm/nocterm.dart';
import 'package:flutter_runtime_mcp/flutter_runtime_mcp.dart';

/// Component for displaying a single Flutter instance in the list
class InstanceListItem extends StatelessComponent {
  final FlutterInstance instance;
  final bool isSelected;
  final int index;

  const InstanceListItem({
    required this.instance,
    required this.isSelected,
    required this.index,
    super.key,
  });

  @override
  Component build(BuildContext context) {
    final statusColor = instance.isRunning ? Colors.green : Colors.red;
    final statusIcon = instance.isRunning ? '●' : '○';
    final device = instance.deviceId ?? 'unknown';
    final duration = _formatDuration(
      DateTime.now().difference(instance.startedAt),
    );

    final bgColor = isSelected
        ? const Color.fromRGB(40, 60, 100)
        : const Color.fromRGB(25, 25, 45);

    final border = isSelected
        ? BoxBorder.all(color: Colors.brightCyan, style: BoxBorderStyle.solid)
        : BoxBorder.all(color: Colors.brightBlack, style: BoxBorderStyle.solid);

    return Container(
      padding: const EdgeInsets.all(1),
      decoration: BoxDecoration(color: bgColor, border: border),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                isSelected ? '▸' : ' ',
                style: const TextStyle(color: Colors.brightCyan),
              ),
              const Text(' '),
              Text(
                '$index.',
                style: const TextStyle(
                  color: Colors.gray,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Text(' '),
              Text(statusIcon, style: TextStyle(color: statusColor)),
              const Text(' '),
              Text(
                device,
                style: const TextStyle(
                  color: Colors.brightWhite,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(duration, style: const TextStyle(color: Colors.yellow)),
            ],
          ),
          const SizedBox(height: 0),
          Row(
            children: [
              const Text('  ID: ', style: TextStyle(color: Colors.gray)),
              Text(
                _truncate(instance.id, 50),
                style: const TextStyle(color: Colors.cyan),
              ),
            ],
          ),
          Row(
            children: [
              const Text('  Dir: ', style: TextStyle(color: Colors.gray)),
              Text(
                _truncate(instance.workingDirectory, 48),
                style: const TextStyle(color: Colors.magenta),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }

  String _truncate(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength - 3)}...';
  }
}
