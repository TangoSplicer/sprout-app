// flutter/lib/screens/onboarding_screen.dart
import 'dart:math';

import 'package:flutter/material.dart';

import '../services/e2ee.dart';
import '../services/project_service.dart';
import 'home_screen.dart';
import 'editor_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _step = 0;
  String _recoveryPhrase = '';
  bool _keysGenerated = false;

  late final List<Widget Function()> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      _buildWelcome,
      _buildSecureSetup,
      _buildAiIntro,
      _buildChooseApp,
      _buildEditorTour,
      _buildFirstRun,
      _buildShare,
      _buildComplete,
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_step](),
      bottomNavigationBar: _step < _screens.length - 1
          ? BottomAppBar(
              child: SizedBox(
                height: 60,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _nextStep,
                      child:
                          Text(_step < _screens.length - 2 ? 'Next' : 'Finish'),
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
                E2EE().generateKeyPair();
                final words = _generateRecoveryPhrase();
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
              style:
                  const TextStyle(fontFamily: 'monospace', color: Colors.blue),
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
                  const Text('Try: "A counter app"',
                      style: TextStyle(fontStyle: FontStyle.italic)),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: _openAiStarter,
                    icon: const Icon(Icons.auto_awesome),
                    label: const Text('Open a guided starter'),
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
            onTap: () => _createTemplateProject('Plant Care'),
          ),
          _ChoiceCard(
            title: 'To-Do List',
            subtitle: 'Simple tasks, no bloat',
            icon: Icons.checklist,
            onTap: () => _createTemplateProject('My Tasks'),
          ),
          _ChoiceCard(
            title: 'Counter',
            subtitle: 'Tap to count anything',
            icon: Icons.add,
            onTap: () => _createTemplateProject('Counter'),
          ),
        ],
      ),
    );
  }

  Future<void> _openAiStarter() async {
    const projectName = 'My First Sprout App';
    try {
      await ProjectService().createProject(projectName);
    } on ProjectException {
      // Reuse the existing guided project if the user revisits onboarding.
    }

    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const EditorScreen(projectName: projectName),
      ),
    );
  }

  Future<void> _createTemplateProject(String name) async {
    try {
      await ProjectService().createProject(name);
      if (mounted) _nextStep();
    } on ProjectException {
      if (mounted) _nextStep();
    }
  }

  String _generateRecoveryPhrase() {
    const words = [
      'amber',
      'birch',
      'cinder',
      'dawn',
      'ember',
      'fern',
      'grove',
      'harbor',
      'iris',
      'jade',
      'kindle',
      'lunar',
      'meadow',
      'north',
      'olive',
      'pine',
      'quartz',
      'river',
      'sage',
      'thistle',
      'umber',
      'vale',
      'willow',
      'zephyr',
    ];
    final random = Random.secure();
    return List<String>.generate(12, (_) => words[random.nextInt(words.length)])
        .join(' ');
  }

  Widget _buildEditorTour() {
    return _buildLessonStep(
      icon: Icons.code_outlined,
      title: 'Make one small change at a time',
      description:
          'Your editor holds the source for this app. Use the AI button for a starter, then keep the parts you like and change the rest.',
      tips: const [
        'Use the save button after a manual edit.',
        'Open the console if you need to understand a compile message.',
        'A short description creates a clearer AI starter.',
      ],
    );
  }

  Widget _buildFirstRun() {
    return _buildLessonStep(
      icon: Icons.play_circle_outline,
      title: 'Preview before you depend on it',
      description:
          'Tap Run to compile your current source and see the labels and actions that it creates. Return to the editor whenever you want to refine it.',
      tips: const [
        'Preview never changes your saved app by itself.',
        'If a preview fails, read the message and adjust the source.',
        'Start with one useful screen, then add more later.',
      ],
    );
  }

  Widget _buildShare() {
    return _buildLessonStep(
      icon: Icons.share_outlined,
      title: 'Share only when you are ready',
      description:
          'Your projects stay on your device. When you choose to share, make sure the receiving person knows what the app is for and how it uses their data.',
      tips: const [
        'Give your app a clear name before sharing it.',
        'Preview it once more before sending a copy.',
        'Keep your recovery phrase private.',
      ],
    );
  }

  Widget _buildComplete() {
    return _buildLessonStep(
      icon: Icons.eco_outlined,
      title: 'You are ready to grow your first tool',
      description:
          'You do not need to learn everything today. Pick one small task, create a starter, and improve it whenever you have a new idea.',
      tips: const [
        'Try a ranked todo list for your first project.',
        'Use Learn Sprout from the home screen whenever you need a refresher.',
      ],
    );
  }

  Widget _buildLessonStep({
    required IconData icon,
    required String title,
    required String description,
    required List<String> tips,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: scheme.primaryContainer,
              foregroundColor: scheme.primary,
              child: Icon(icon, size: 32),
            ),
            const SizedBox(height: 24),
            Text(title,
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            Text(description, style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 24),
            ...tips.map(
              (tip) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.check_circle_outline,
                        size: 20, color: scheme.primary),
                    const SizedBox(width: 10),
                    Expanded(child: Text(tip)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _ChoiceCard(
      {required this.title,
      required this.subtitle,
      required this.icon,
      required this.onTap});

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
