import 'package:flutter/material.dart';

import '../theme/sprout_theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: SproutTheme.sage,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.tune_outlined, color: scheme.primary, size: 34),
                const SizedBox(height: 12),
                Text(
                  'Keep Sprout calm and predictable.',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: SproutTheme.ink,
                      ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Your projects are stored locally. Review exactly what a generated starter will do before you preview or share it.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'How Sprout works',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 10),
          const _SettingsCard(
            icon: Icons.auto_awesome_outlined,
            title: 'Starter planning',
            body:
                'A capability-aware local planner creates editable starters for tasks, notes, habits, navigation, reminders, and events.',
            badge: 'Works offline',
          ),
          const _SettingsCard(
            icon: Icons.notifications_active_outlined,
            title: 'Reminders',
            body:
                'Sprout asks for notification permission only when you tap a reminder action in a preview.',
            badge: 'Ask when needed',
          ),
          const _SettingsCard(
            icon: Icons.save_outlined,
            title: 'Saving',
            body:
                'Use Save in the editor to keep manual changes. Accepted starters are saved when you apply them.',
            badge: 'On this device',
          ),
          const SizedBox(height: 16),
          Text(
            'Privacy',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 10),
          Card(
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: CircleAvatar(
                backgroundColor: scheme.primaryContainer,
                foregroundColor: scheme.primary,
                child: const Icon(Icons.privacy_tip_outlined),
              ),
              title: const Text('Local project storage'),
              subtitle: const Text(
                'Your app source stays on the device unless you explicitly choose to share it.',
              ),
              trailing: const Icon(Icons.info_outline),
              onTap: () => showAboutDialog(
                context: context,
                applicationName: 'Sprout',
                applicationVersion: 'Test build',
                children: const [
                  Text(
                    'Sprout stores project source locally. Review generated code and reminder permissions before using or sharing a project.',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final String badge;

  const _SettingsCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: scheme.primaryContainer,
                foregroundColor: scheme.primary,
                child: Icon(icon),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(body),
                    const SizedBox(height: 10),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: scheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        child: Text(
                          badge,
                          style:
                              Theme.of(context).textTheme.labelMedium?.copyWith(
                                    color: scheme.onSecondaryContainer,
                                    fontWeight: FontWeight.w800,
                                  ),
                        ),
                      ),
                    ),
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
