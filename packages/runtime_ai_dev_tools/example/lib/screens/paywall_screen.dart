import 'package:flutter/material.dart';

class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  final _subscribeButtonKey = GlobalKey();
  final _restoreButtonKey = GlobalKey();
  final _closeButtonKey = GlobalKey();

  String _selectedPlan = 'yearly';

  @override
  void initState() {
    super.initState();
    // Log button positions after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _logButtonPositions();
    });
  }

  void _logButtonPositions() {
    _logButtonPosition('Subscribe', _subscribeButtonKey);
    _logButtonPosition('Restore', _restoreButtonKey);
    _logButtonPosition('Close', _closeButtonKey);
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
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Upgrade to Premium'),
        backgroundColor: theme.colorScheme.inversePrimary,
        leading: IconButton(
          key: _closeButtonKey,
          icon: const Icon(Icons.close),
          onPressed: () {
            print('🎯 Close button pressed!');
            _logButtonPositions();
            Navigator.pop(context);
          },
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              const Icon(
                Icons.workspace_premium,
                size: 80,
                color: Colors.amber,
              ),
              const SizedBox(height: 16),
              const Text(
                'Unlock Premium Features',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Get unlimited access to all features',
                style: TextStyle(
                  fontSize: 16,
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // Premium Features
              _buildFeatureItem(
                icon: Icons.cloud_sync,
                title: 'Cloud Sync',
                description: 'Sync your data across all devices',
              ),
              const SizedBox(height: 16),
              _buildFeatureItem(
                icon: Icons.block,
                title: 'Ad-Free Experience',
                description: 'Enjoy the app without any interruptions',
              ),
              const SizedBox(height: 16),
              _buildFeatureItem(
                icon: Icons.speed,
                title: 'Priority Support',
                description: 'Get help faster with premium support',
              ),
              const SizedBox(height: 16),
              _buildFeatureItem(
                icon: Icons.auto_awesome,
                title: 'Exclusive Features',
                description: 'Access to beta features and early releases',
              ),
              const SizedBox(height: 32),

              // Subscription Plans
              const Text(
                'Choose Your Plan',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              // Monthly Plan
              _buildPlanCard(
                context: context,
                planId: 'monthly',
                title: 'Monthly',
                price: '\$9.99',
                period: '/month',
                description: 'Billed monthly',
                isSelected: _selectedPlan == 'monthly',
                onTap: () {
                  setState(() {
                    _selectedPlan = 'monthly';
                  });
                  print('📦 Monthly plan selected');
                },
              ),
              const SizedBox(height: 12),

              // Yearly Plan (Best Value)
              Stack(
                children: [
                  _buildPlanCard(
                    context: context,
                    planId: 'yearly',
                    title: 'Yearly',
                    price: '\$79.99',
                    period: '/year',
                    description: 'Save 33% - Best Value!',
                    isSelected: _selectedPlan == 'yearly',
                    onTap: () {
                      setState(() {
                        _selectedPlan = 'yearly';
                      });
                      print('📦 Yearly plan selected');
                    },
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.amber,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'BEST VALUE',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Subscribe Button
              ElevatedButton(
                key: _subscribeButtonKey,
                onPressed: () {
                  print('🎯 Subscribe button pressed! Plan: $_selectedPlan');
                  _logButtonPositions();
                  _showSubscriptionDialog(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  padding: const EdgeInsets.all(20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Subscribe Now',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 16),

              // Restore Purchases Button
              TextButton(
                key: _restoreButtonKey,
                onPressed: () {
                  print('🎯 Restore purchases button pressed!');
                  _logButtonPositions();
                  _showRestoreDialog(context);
                },
                child: const Text(
                  'Restore Purchases',
                  style: TextStyle(fontSize: 16),
                ),
              ),
              const SizedBox(height: 16),

              // Terms and Privacy
              Text(
                'By subscribing, you agree to our Terms of Service and Privacy Policy. '
                'Subscription automatically renews unless cancelled at least 24 hours before the end of the current period.',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurface.withOpacity(0.5),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureItem({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.blue, size: 28),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPlanCard({
    required BuildContext context,
    required String planId,
    required String title,
    required String price,
    required String period,
    required String description,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.outline.withOpacity(0.3),
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(16),
          color: isSelected
              ? theme.colorScheme.primary.withOpacity(0.05)
              : null,
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.check_circle : Icons.circle_outlined,
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outline,
              size: 28,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 14,
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  price,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  period,
                  style: TextStyle(
                    fontSize: 14,
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showSubscriptionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Subscription Confirmation'),
          content: Text(
            'You have selected the ${_selectedPlan == 'monthly' ? 'Monthly (\$9.99/month)' : 'Yearly (\$79.99/year)'} plan.\n\n'
            'In a real app, this would trigger the in-app purchase flow.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _showSuccessDialog(context);
              },
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );
  }

  void _showSuccessDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 28),
              SizedBox(width: 12),
              Text('Success!'),
            ],
          ),
          content: const Text(
            'Your subscription is now active!\n\n'
            'This is a demo - no actual purchase was made.',
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context); // Return to home
              },
              child: const Text('Great!'),
            ),
          ],
        );
      },
    );
  }

  void _showRestoreDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Restore Purchases'),
          content: const Text(
            'Checking for previous purchases...\n\n'
            'In a real app, this would check the app store for existing subscriptions.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('No previous purchases found (demo)'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              child: const Text('Restore'),
            ),
          ],
        );
      },
    );
  }
}
