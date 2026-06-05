import 'package:flutter/material.dart';

class MoodSelector extends StatelessWidget {
  const MoodSelector({super.key});

  @override
  Widget build(BuildContext context) {
    final moods = [
      {'icon': '☀️', 'label': 'Rạng rỡ'},
      {'icon': '😊', 'label': 'Hài lòng'},
      {'icon': '☁️', 'label': 'Êm đềm'},
      {'icon': '🌧️', 'label': 'U sầu'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Tâm trạng hiện tại', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: moods.map((mood) => _buildMoodItem(mood['icon']!, mood['label']!)).toList(),
        ),
      ],
    );
  }

  Widget _buildMoodItem(String icon, String label) {
    return Container(
      width: 75,
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          Text(icon, style: const TextStyle(fontSize: 24)),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}