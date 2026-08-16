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
                  'Start from a working local pattern, make it yours, and safely preview it before sharing a complete copy with someone else.',
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
            title: 'Choose a working starting point',
            body:
                'Create an app, give it a clear name, and pick a useful local pattern such as a goal tracker, budget, or contact organiser.',
          ),
          const _LessonCard(
            number: '2',
            icon: Icons.play_arrow_outlined,
            title: 'Use it before changing it',
            body:
                'Choose Run my app to try the forms, buttons, calculations, and saved local data straight away.',
          ),
          const _LessonCard(
            number: '3',
            icon: Icons.code_outlined,
            title: 'Change only what you need',
            body:
                'Open the source when you are ready. Language review and reusable snippets help you add controls without starting from scratch.',
          ),
          const _LessonCard(
            number: '4',
            icon: Icons.play_circle_outline,
            title: 'Preview before you rely on it',
            body:
                'Run the same interactive experience other people will use. Your changes and app data save locally to this project.',
          ),
          const _LessonCard(
            number: '5',
            icon: Icons.share_outlined,
            title: 'Share or add it to your home screen',
            body:
                'Share a complete editable app package with another Sprout user, or add a named home-screen icon that opens your app in Sprout.',
          ),
          const SizedBox(height: 24),
          Text('Advanced Capabilities',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  )),
          const SizedBox(height: 12),
          const _LessonCard(
            number: '6',
            icon: Icons.sync_alt_outlined,
            title: 'Sprout Connect (P2P Sync)',
            body:
                'Collaborate securely by syncing data between people sharing the same app over your local network with explicit consent.',
          ),
          const _LessonCard(
            number: '7',
            icon: Icons.notifications_active_outlined,
            title: 'Native Notifications',
            body:
                'Keep users informed with immediate device alerts and reminders triggered by app actions.',
          ),
          const _LessonCard(
            number: '8',
            icon: Icons.bar_chart_rounded,
            title: 'Visual Insights & Media',
            body:
                'Add interactive charts to visualize trends and audio players for voice notes or soundscapes directly in your app.',
          ),
          const _LessonCard(
            number: '9',
            icon: Icons.public_outlined,
            title: 'Safe Web Connectivity',
            body:
                'Fetch live data from public APIs into your app state while maintaining a strict local-first security model.',
          ),
          const SizedBox(height: 12),
          Text(
            'Tip: begin with a pattern that already works, then make one useful change at a time. You remain in control of every screen, record, and shared package.',
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
