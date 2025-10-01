// lib/widgets/add_note_widgets.dart
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class PickOptionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const PickOptionCard({super.key, required this.icon, required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: SizedBox(
          width: 140,
          height: 120,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 38, color: Colors.deepPurple),
              const SizedBox(height: 8),
              Text(title, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

class PreviewTextCard extends StatelessWidget {
  final String text;
  final VoidCallback onEdit;

  const PreviewTextCard({super.key, required this.text, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.article_outlined, color: Colors.deepPurple),
                const SizedBox(width: 8),
                const Text('Extracted Text', style: TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                TextButton(onPressed: onEdit, child: const Text('Edit')),
              ],
            ),
            const SizedBox(height: 8),
            Text(text, style: const TextStyle(height: 1.4)),
          ],
        ),
      ),
    );
  }
}

class SmallSwitchTile extends StatelessWidget {
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  const SmallSwitchTile({super.key, required this.title, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(title),
      trailing: CupertinoSwitch(value: value, onChanged: onChanged),
    );
  }
}
