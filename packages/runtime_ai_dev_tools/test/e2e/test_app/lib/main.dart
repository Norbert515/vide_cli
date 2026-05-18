import 'package:flutter/material.dart';
import 'package:runtime_ai_dev_tools/runtime_ai_dev_tools.dart';

void main() {
  runDebugApp(const TestApp());
}

class TestApp extends StatelessWidget {
  const TestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'E2E Test App',
      debugShowCheckedModeBanner: false,
      home: const TestScreen(),
    );
  }
}

class TestScreen extends StatefulWidget {
  const TestScreen({super.key});

  @override
  State<TestScreen> createState() => _TestScreenState();
}

class _TestScreenState extends State<TestScreen> {
  int _counter = 0;
  String _typedText = '';
  bool _checked = false;
  bool _switchValue = false;
  final _textController = TextEditingController();

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('E2E Test App'),
      ),
      body: SingleChildScrollView(
        key: const Key('main_scroll_view'),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Tap section
              const Text('Tap Section',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(
                'Counter: $_counter',
                key: const Key('counter_display'),
                style: const TextStyle(fontSize: 24),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                key: const Key('increment_button'),
                onPressed: () {
                  setState(() {
                    _counter++;
                  });
                },
                child: const Text('Increment'),
              ),
              const SizedBox(height: 24),

              // Text Input section
              const Text('Text Input Section',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextField(
                key: const Key('text_field'),
                controller: _textController,
                decoration: const InputDecoration(
                  labelText: 'Type here',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) {
                  setState(() {
                    _typedText = value;
                  });
                },
              ),
              const SizedBox(height: 8),
              Text(
                'Typed: $_typedText',
                key: const Key('typed_text_display'),
              ),
              const SizedBox(height: 24),

              // Checkbox section
              const Text('Checkbox Section',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              CheckboxListTile(
                key: const Key('checkbox_tile'),
                title: const Text('Check me'),
                value: _checked,
                onChanged: (value) {
                  setState(() {
                    _checked = value ?? false;
                  });
                },
              ),
              Text(
                'Checked: $_checked',
                key: const Key('checkbox_display'),
              ),
              const SizedBox(height: 24),

              // Scroll section
              const Text('Scroll Section',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              SizedBox(
                height: 200,
                child: ListView.builder(
                  key: const Key('scroll_list'),
                  itemCount: 50,
                  itemBuilder: (context, index) {
                    return ListTile(
                      title: Text('Item $index'),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),

              // Switch section
              const Text('Switch Section',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              SwitchListTile(
                key: const Key('switch_tile'),
                title: const Text('Toggle me'),
                value: _switchValue,
                onChanged: (value) {
                  setState(() {
                    _switchValue = value;
                  });
                },
              ),
              const SizedBox(height: 24),

              // Bottom marker for scroll verification
              Padding(
                padding: const EdgeInsets.only(bottom: 32.0),
                child: Text(
                  'Bottom of page',
                  key: const Key('bottom_marker'),
                  style: const TextStyle(
                      fontSize: 16, fontStyle: FontStyle.italic),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
