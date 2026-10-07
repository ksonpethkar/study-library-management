import 'package:flutter/material.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Terms of Service')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: const [
          Text('Terms of Service', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          SizedBox(height: 16),
          Text(
            '1. Acceptance of Terms\nBy accessing or using this app, you agree to be bound by these Terms of Service.\n\n'
            '2. Use of Service\nYou must use the service only for lawful purposes and in accordance with these Terms.\n\n'
            '3. User Accounts\nYou are responsible for safeguarding the password that you use to access the service.\n\n'
            '4. Modifications\nWe reserve the right to modify or replace these Terms at any time.',
            style: TextStyle(fontSize: 16, height: 1.5),
          ),
        ],
      ),
    );
  }
}
