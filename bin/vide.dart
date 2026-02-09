import 'package:vide_cli/cli/vide_command_runner.dart';

Future<void> main(List<String> args) async {
  final runner = VideCommandRunner();
  await runner.run(args);
}
