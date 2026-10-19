import 'package:flutter/material.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: colors.primary.withValues(alpha: 0.12),
                child: Icon(
                  Icons.dashboard_customize,
                  color: colors.primary,
                  size: 36,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Second Brain',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              const Text('Offline-first notes with attachments'),
              const SizedBox(height: 16),
              const Text('Version 1.0.0 (build 1)'),
              const SizedBox(height: 16),
              FilledButton.icon(
                icon: const Icon(Icons.article_outlined),
                label: const Text('Licenses'),
                onPressed: () => showLicensePage(context: context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
