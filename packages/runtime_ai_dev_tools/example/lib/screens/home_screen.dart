import 'package:flutter/material.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _galleryButtonKey = GlobalKey();
  final _formButtonKey = GlobalKey();
  final _paywallButtonKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    // Log button positions after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _logButtonPositions();
    });
  }

  void _logButtonPositions() {
    _logButtonPosition('Gallery', _galleryButtonKey);
    _logButtonPosition('Form', _formButtonKey);
    _logButtonPosition('Paywall', _paywallButtonKey);
  }

  void _logButtonPosition(String name, GlobalKey key) {
    final renderBox = key.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox != null) {
      final position = renderBox.localToGlobal(Offset.zero);
      final size = renderBox.size;
      final center = Offset(
        position.dx + size.width / 2,
        position.dy + size.height / 2,
      );

      print('📍 [$name Button]');
      print(
        '   Position: (${position.dx.toStringAsFixed(1)}, ${position.dy.toStringAsFixed(1)})',
      );
      print(
        '   Size: ${size.width.toStringAsFixed(1)} x ${size.height.toStringAsFixed(1)}',
      );
      print(
        '   Center: (${center.dx.toStringAsFixed(1)}, ${center.dy.toStringAsFixed(1)})',
      );
      print(
        '   Bounds: x[${position.dx.toStringAsFixed(1)} - ${(position.dx + size.width).toStringAsFixed(1)}], '
        'y[${position.dy.toStringAsFixed(1)} - ${(position.dy + size.height).toStringAsFixed(1)}]',
      );
    } else {
      print('⚠️  [$name Button] RenderBox not found');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Runtime AI Dev Tools Example'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.phone_android, size: 80, color: Colors.blue),
              const SizedBox(height: 24),
              const Text(
                'Welcome to Runtime AI Dev Tools',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Text(
                'This example app demonstrates service extensions for AI-assisted testing',
                style: TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: 200,
                child: ElevatedButton.icon(
                  key: _galleryButtonKey,
                  onPressed: () {
                    print('🎯 Gallery button pressed!');
                    _logButtonPositions(); // Log positions on press
                    Navigator.pushNamed(context, '/gallery');
                  },
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Gallery'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: 200,
                child: ElevatedButton.icon(
                  key: _formButtonKey,
                  onPressed: () {
                    print('🎯 Form button pressed!');
                    _logButtonPositions(); // Log positions on press
                    Navigator.pushNamed(context, '/form');
                  },
                  icon: const Icon(Icons.edit),
                  label: const Text('Form'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: 200,
                child: ElevatedButton.icon(
                  key: _paywallButtonKey,
                  onPressed: () {
                    print('🎯 Paywall button pressed!');
                    _logButtonPositions(); // Log positions on press
                    Navigator.pushNamed(context, '/paywall');
                  },
                  icon: const Icon(Icons.workspace_premium),
                  label: const Text('Paywall'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
