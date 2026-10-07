import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy Policy')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: const [
          Text('Privacy Policy', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          SizedBox(height: 16),
          Text(
            'What Data We Collect\nWe collect personal information such as your name, email, and phone number when you register.\n\n'
            'Why We Collect It\nTo provide and maintain our Service, including to monitor the usage of our Service.\n\n'
            'How It Is Stored\nYour data is stored securely on cloud servers provided by Firebase.\n\n'
            'Security\nThe security of your data is important to us, but remember that no method of transmission over the Internet is 100% secure.\n\n'
            'Deletion Rights\nYou have the right to delete your account and all associated data at any time from the app settings.',
            style: TextStyle(fontSize: 16, height: 1.5),
          ),
        ],
      ),
    );
  }
}
