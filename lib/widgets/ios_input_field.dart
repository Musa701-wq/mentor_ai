// lib/widgets/ios_input_field.dart
import 'package:flutter/cupertino.dart';

class IOSInputField extends StatelessWidget {
  final String label;
  final TextEditingController controller;

  const IOSInputField({super.key, required this.label, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        CupertinoTextField(
          controller: controller,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: CupertinoColors.systemGrey6,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ],
    );
  }
}
