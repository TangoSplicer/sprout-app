// flutter/lib/screens/onboarding_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/e2ee.dart';
import '../services/ai_assistant.dart';
import 'home_screen.dart';
import 'ai_screen.dart';
import 'share_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _step = 0;
  String _recoveryPhrase = '';
  bool _keysGenerated = false;

  final List<Widget Function()> _screens = [
    _buildWelcome,
    _buildSecureSetup,
    _buildAiIntro,
    _buildChooseApp,
    _buildEditorTour,
    _buildFirstRun,
    _buildShare,
    _buildComplete,
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_step](),
      bottomNavigationBar: _step < _screens.length - 1
          ? BottomAppBar(
              child: Container(
                height: 60,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _nextStep,
                      child: Text(_step < _screens.length - 2 ? 'Next' : 'Finish'),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }

  void _nextStep() {
    if (_step < _screens.length - 1) {
      setState(() => _step++);
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    }
  }

  Widget _buildWelcome() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFE8F5E9), Color(0xFFC8E6C9)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset('assets/logo_sprout.png', height: 120),
          const SizedBox(height: 24),
          const Text(
            'Your idea is a seed.',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const Text(
            'Let’s grow your first app — safely.',
            style: TextStyle(fontSize: 18, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSecureSetup() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '🔐 Secure Your Apps',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          const Text(
              'Sprout encrypts your apps so only you can read them. '
              'No one else — not even us — can access your tools.',
              style: TextStyle(fontSize: 16)),
          const SizedBox(height: 24),
          if (!_keysGenerated)
            ElevatedButton(
              onPressed: () {
                final keyPair = E2EE().generateKeyPair();
                final words = _generateRecoveryPhrase(); // In real app: derive from key
                setState(() {
                  _recoveryPhrase = words;
                  _keysGenerated = true;
                });
              },
              child: const Text('Create Keys'),
            )
          else ...[
            const Text('Recovery Phrase:'),
            SelectableText(
              _recoveryPhrase,
              style: const TextStyle(fontFamily: 'monospace', color: Colors.blue),
            ),
            const Text('Write this down. You’ll need it to recover your apps.'),
          ],
          const SizedBox(height: 16),
          if (_keysGenerated)
            ElevatedButton(
              onPressed: _nextStep,
              child: const Text("I've Saved It"),
            ),
        ],
      ),
    );
  }

  Widget _buildAiIntro() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '🤖 Meet Your AI Assistant',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          const Text(
            'You don’t need to remember syntax. Just tell Sprout what you want.',
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Text('Try: "A counter app"', style: TextStyle(fontStyle: FontStyle.italic)),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AIScreen(projectName: 'Counter'),
                        ),
                      );
                    },
                    child: const Text('Try It'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChooseApp() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'What would you like to grow?',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          _ChoiceCard(
            title: 'Water My Plants',
            subtitle: 'Reminders for your green friends',
            icon: Icons.eco,
            onTap: () {
              ProjectService().createProject('Plant Care');
              _nextStep();
            },
          ),
          _ChoiceCard(
            title: 'To-Do List',
            subtitle: 'Simple tasks, no bloat',
            icon: Icons.checklist,
            onTap: () {
              ProjectService().createProject('My Tasks');
              _nextStep();
            },
          ),
          _ChoiceCard(
            title: 'Counter',
            subtitle: 'Tap to count anything',
            icon: Icons.add,
            onTap: () {
              ProjectService().createProject('Counter');
              _nextStep();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEditorTour() {
    return Container(
      color: Colors.white,
      child: const Center(
        child: Text('Editor Tour (3-step overlay)'),
      ),
    );
  }

  Widget _buildFirstRun() {
    return Container(
      color: Colors.white,
      child: const Center(
        child: Text('Preview & Install Flow'),
      ),
    );
  }

  Widget _buildShare() {
    return Container(
      color: Colors.white,
      child: const Center(
        child: Text('QR Share Screen'),
      ),
    );
  }

  Widget _buildComplete() {
    return Container(
      color: Colors.white,
      child: const Center(
        child: Text('Onboarding Complete!'),
      ),
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _ChoiceCard({required this.title, required this.subtitle, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF4A9D5E)),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}