import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_pty/flutter_pty.dart';
import 'package:xterm/xterm.dart';

class TerminalPage extends StatefulWidget {
  const TerminalPage({super.key});

  @override
  State<TerminalPage> createState() => _TerminalPageState();
}

class _TerminalPageState extends State<TerminalPage> {
  late Terminal _terminal;
  late TerminalController _terminalController;
  Pty? _pty;
  bool _isRunning = false;
  int? _exitCode;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _terminal = Terminal(maxLines: 10000);
    _terminalController = TerminalController();

    // Wait for terminal to get its size from TerminalView before starting PTY
    _terminal.onResize = (width, height, pixelWidth, pixelHeight) {
      debugPrint('Terminal onResize: ${width}x$height (pty=${_pty != null})');
      // Start PTY on first resize (when terminal gets its actual size)
      if (_pty == null && width > 0 && height > 0) {
        // Schedule PTY start after the current frame to avoid setState during layout
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_pty == null && mounted) {
            _startPtyWithSize(width, height);
          }
        });
      } else if (_pty != null) {
        // After PTY is started, resize it when terminal resizes
        _pty!.resize(height, width);
      }
    };
  }

  @override
  void dispose() {
    _pty?.kill();
    _terminalController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  String _getShell() {
    if (Platform.isMacOS || Platform.isLinux) {
      return Platform.environment['SHELL'] ?? '/bin/bash';
    }
    return 'cmd.exe';
  }

  /// Returns the path to the vide repo root.
  String _getRepoRoot() {
    // First: check environment variable
    final envRoot = Platform.environment['VIDE_REPO_ROOT'];
    if (envRoot != null && envRoot.isNotEmpty) {
      return envRoot;
    }

    // Second: derive from this file's location using a compile-time constant
    const thisFile = String.fromEnvironment(
      'VIDE_TERMINAL_SOURCE',
      defaultValue: '',
    );
    if (thisFile.isNotEmpty) {
      var dir = Directory(thisFile).parent.parent.parent.parent;
      if (_isVideRepo(dir.path)) {
        return dir.path;
      }
    }

    // Third: search from current working directory upward
    var dir = Directory.current;
    for (var i = 0; i < 10; i++) {
      if (_isVideRepo(dir.path)) {
        return dir.path;
      }
      final parent = dir.parent;
      if (parent.path == dir.path) break;
      dir = parent;
    }

    // Fourth: try common development locations
    final home = Platform.environment['HOME'] ?? '';
    final commonPaths = [
      '$home/IdeaProjects/vide_cli',
      '$home/IdeaProjects/vide_cli-flutter-terminal',
      '$home/projects/vide_cli',
      '$home/dev/vide_cli',
    ];
    for (final path in commonPaths) {
      if (_isVideRepo(path)) {
        return path;
      }
    }

    return Directory.current.path;
  }

  bool _isVideRepo(String path) {
    final pubspec = File('$path/pubspec.yaml');
    if (pubspec.existsSync()) {
      final content = pubspec.readAsStringSync();
      return content.contains('name: vide_cli');
    }
    return false;
  }

  String _getWorkingDirectory() {
    return Platform.environment['HOME'] ?? Directory.current.path;
  }

  void _startPtyWithSize(int cols, int rows) {
    final shell = _getShell();
    final repoRoot = _getRepoRoot();
    final workingDir = _getWorkingDirectory();

    // Prepare environment - start fresh to avoid Flutter's dart in PATH
    final environment = <String, String>{
      'TERM': 'xterm-256color',
      'HOME': Platform.environment['HOME'] ?? '',
      'USER': Platform.environment['USER'] ?? '',
      'LANG': Platform.environment['LANG'] ?? 'en_US.UTF-8',
      'PATH': Platform.environment['PATH'] ?? '/usr/local/bin:/usr/bin:/bin',
    };

    final command = 'cd "$repoRoot" && dart run bin/vide.dart';

    // Debug: print the size being used
    debugPrint('Starting PTY with size: ${cols}x$rows');

    _pty = Pty.start(
      shell,
      arguments: ['-l', '-c', command],
      environment: environment,
      workingDirectory: workingDir,
      columns: cols,
      rows: rows,
    );

    // Connect PTY output to terminal with proper UTF-8 decoding
    _pty!.output
        .cast<List<int>>()
        .transform(const Utf8Decoder(allowMalformed: true))
        .listen(
          (data) {
            _terminal.write(data);
          },
          onDone: () async {
            final exitCode = await _pty?.exitCode;
            if (mounted) {
              setState(() {
                _isRunning = false;
                _exitCode = exitCode;
              });
            }
          },
        );

    // Connect terminal output to PTY input
    _terminal.onOutput = (data) {
      _pty?.write(const Utf8Encoder().convert(data));
    };

    // Note: onResize is already set up in initState to handle PTY resize

    setState(() {
      _isRunning = true;
      _exitCode = null;
    });
  }

  void _restartPty() {
    _pty?.kill();
    _pty = null;
    _terminal.buffer.clear();
    _terminal.buffer.setCursor(0, 0);
    // Use current terminal size
    final cols = _terminal.viewWidth > 0 ? _terminal.viewWidth : 80;
    final rows = _terminal.viewHeight > 0 ? _terminal.viewHeight : 24;
    _startPtyWithSize(cols, rows);
  }

  void _copySelection() {
    final selection = _terminalController.selection;
    if (selection == null) return;

    final text = _terminal.buffer.getText(selection);
    if (text.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: text));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Copied to clipboard'),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null) {
      _pty?.write(const Utf8Encoder().convert(data!.text!));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Status bar
          Container(
            height: 32,
            color: const Color(0xFF323233),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Icon(
                  _isRunning ? Icons.circle : Icons.circle_outlined,
                  size: 12,
                  color: _isRunning ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 8),
                Text(
                  _isRunning
                      ? 'Vide Terminal'
                      : 'Exited${_exitCode != null ? ' (code: $_exitCode)' : ''}',
                  style: const TextStyle(fontSize: 13),
                ),
                const Spacer(),
                if (!_isRunning)
                  TextButton.icon(
                    onPressed: _restartPty,
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Restart'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white70,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
              ],
            ),
          ),
          // Terminal
          Expanded(
            child: GestureDetector(
              onSecondaryTapDown: (details) {
                _showContextMenu(context, details.globalPosition);
              },
              child: TerminalView(
                _terminal,
                controller: _terminalController,
                focusNode: _focusNode,
                autofocus: true,
                theme: _terminalTheme,
                textStyle: const TerminalStyle(
                  fontSize: 14,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showContextMenu(BuildContext context, Offset position) {
    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx,
        position.dy,
      ),
      items: [
        const PopupMenuItem(
          value: 'copy',
          child: Row(
            children: [
              Icon(Icons.copy, size: 18),
              SizedBox(width: 8),
              Text('Copy'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'paste',
          child: Row(
            children: [
              Icon(Icons.paste, size: 18),
              SizedBox(width: 8),
              Text('Paste'),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'restart',
          child: Row(
            children: [
              Icon(Icons.refresh, size: 18),
              SizedBox(width: 8),
              Text('Restart'),
            ],
          ),
        ),
      ],
    ).then((value) {
      switch (value) {
        case 'copy':
          _copySelection();
          break;
        case 'paste':
          _paste();
          break;
        case 'restart':
          _restartPty();
          break;
      }
    });
  }

  TerminalTheme get _terminalTheme => const TerminalTheme(
    cursor: Color(0xFFAEAFAD),
    selection: Color(0xFF264F78),
    foreground: Color(0xFFCCCCCC),
    background: Color(0xFF1E1E1E),
    black: Color(0xFF000000),
    red: Color(0xFFCD3131),
    green: Color(0xFF0DBC79),
    yellow: Color(0xFFE5E510),
    blue: Color(0xFF2472C8),
    magenta: Color(0xFFBC3FBC),
    cyan: Color(0xFF11A8CD),
    white: Color(0xFFE5E5E5),
    brightBlack: Color(0xFF666666),
    brightRed: Color(0xFFF14C4C),
    brightGreen: Color(0xFF23D18B),
    brightYellow: Color(0xFFF5F543),
    brightBlue: Color(0xFF3B8EEA),
    brightMagenta: Color(0xFFD670D6),
    brightCyan: Color(0xFF29B8DB),
    brightWhite: Color(0xFFFFFFFF),
    searchHitBackground: Color(0xFFFFDF5D),
    searchHitBackgroundCurrent: Color(0xFFFF9632),
    searchHitForeground: Color(0xFF000000),
  );
}
