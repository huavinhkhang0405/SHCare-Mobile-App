import 'package:flutter/material.dart';

import '../../../utils/date_formatter.dart';
import '../../../core/config/app_localizations.dart';

class GreetingSection extends StatelessWidget {
  final String name;

  const GreetingSection({super.key, required this.name});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final greeting = DateFormatter.greeting(DateFormatter.nowLocal(), context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$greeting, $name!',
          style: textTheme.displayLarge?.copyWith(fontSize: 28),
        ),
        const SizedBox(height: 4),
        Text(
          context.tr('greeting_subtitle'),
          style: textTheme.bodyMedium,
        ),
      ],
    );
  }
}
