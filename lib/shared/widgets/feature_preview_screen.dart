import 'package:flutter/material.dart';

class PreviewActivity {
  final IconData icon;
  final String title;
  final String description;
  final String label;

  const PreviewActivity({
    required this.icon,
    required this.title,
    required this.description,
    this.label = 'Sắp ra mắt',
  });
}

class FeaturePreviewScreen extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final MaterialColor color;
  final List<PreviewActivity> activities;

  const FeaturePreviewScreen({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.activities,
  });

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [color.shade700, color.shade400]),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 42, color: Colors.white),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: const TextStyle(color: Colors.white, fontSize: 15),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Khu vực luyện tập',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        for (final activity in activities)
          Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: CircleAvatar(
                backgroundColor: color.shade50,
                foregroundColor: color.shade800,
                child: Icon(activity.icon),
              ),
              title: Text(
                activity.title,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(activity.description),
              ),
              trailing: Chip(
                label: Text(activity.label),
                visualDensity: VisualDensity.compact,
              ),
            ),
          ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.shade50,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Icon(Icons.construction, color: color.shade800),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Các khu vực đã được thiết kế. Bài luyện tương tác sẽ được bổ sung trong các bản cập nhật tiếp theo.',
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
