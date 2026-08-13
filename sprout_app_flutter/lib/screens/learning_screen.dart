import 'package:flutter/material.dart';

class LearningScreen extends StatelessWidget {
  const LearningScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Learn Sprout')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: scheme.primaryContainer,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.school_outlined, size: 36, color: scheme.primary),
                const SizedBox(height: 12),
                Text(
                  'Start with an idea, not code.',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: scheme.onPrimaryContainer,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Sprout turns a simple description into a small personal tool. '
                  'You can safely inspect, adjust, and preview it before sharing.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: scheme.onPrimaryContainer,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text('Your first five minutes',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  )),
          const SizedBox(height: 12),
          const _LessonCard(
            number: '1',
            icon: Icons.add_circle_outline,
            title: 'Create a small app',
            body:
                'Choose New App and give your tool a clear name, such as “Weekly Tasks”.',
          ),
          const _LessonCard(
            number: '2',
            icon: Icons.smart_toy_outlined,
            title: 'Ask for a starter',
            body:
                'In the editor, select the AI button and describe what you need: “A ranked todo list for my week.”',
          ),
          const _LessonCard(
            number: '3',
            icon: Icons.check_circle_outline,
            title: 'Use and save it',
            body:
                'Choose Use to replace the starter code. Sprout saves the accepted version to your project automatically.',
          ),
          const _LessonCard(
            number: '4',
            icon: Icons.play_circle_outline,
            title: 'Preview before you rely on it',
            body:
                'Tap Run to check the labels and buttons your app will show. Return to the editor whenever you want to refine it.',
          ),
          const _LessonCard(
            number: '5',
            icon: Icons.share_outlined,
            title: 'Keep growing',
            body:
                'Use Share when you are ready to give a copy to someone else. Start with one useful screen and improve it over time.',
          ),
          const SizedBox(height: 12),
          Text(
            'Tip: short, specific requests create the clearest starting point. You stay in control of every change.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}

class _LessonCard extends StatelessWidget {
  final String number;
  final IconData icon;
  final String title;
  final String body;

  const _LessonCard({
    required this.number,
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: scheme.primaryContainer,
                foregroundColor: scheme.primary,
                child: Text(number,
                    style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(icon, size: 20, color: scheme.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(title,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w800)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(body),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
