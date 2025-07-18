import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

class HelpFeedbackScreen extends StatelessWidget {
  const HelpFeedbackScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Support'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            Expanded(
              child: ListView(
                children: [
                  _buildSupportCard(
                    context,
                    icon: LucideIcons.helpCircle,
                    title: 'FAQ',
                    subtitle: 'Most of your questions answered.',
                    route: '/faq',
                  ),
                  _buildSupportCard(
                    context,
                    icon: LucideIcons.messageCircle,
                    title: 'Chat',
                    subtitle: 'Need help? We are here.',
                    route: '/chat',
                  ),
                  _buildSupportCard(
                    context,
                    icon: LucideIcons.star,
                    title: 'Feedback',
                    subtitle: 'Rate and help us improve.',
                    route: '/feedback',
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildSupportCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    String? route,
  }) {
    return GestureDetector(
      onTap: route != null ? () => Navigator.pushNamed(context, route) : null,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha((0.1 * 255).round()),
              blurRadius: 8,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: Theme.of(context)
                  .colorScheme
                  .secondary
                  .withAlpha((0.15 * 255).round()),
              child: Icon(icon, color: Theme.of(context).colorScheme.secondary),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(subtitle,
                      style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 16)
          ],
        ),
      ),
    );
  }
}
