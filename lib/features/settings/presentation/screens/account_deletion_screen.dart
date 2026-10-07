import 'package:flutter/material.dart';

class AccountDeletionScreen extends StatefulWidget {
  const AccountDeletionScreen({super.key});

  @override
  State<AccountDeletionScreen> createState() => _AccountDeletionScreenState();
}

class _AccountDeletionScreenState extends State<AccountDeletionScreen> {
  final _controller = TextEditingController();
  bool _agreed = false;
  
  bool get _canDelete => _agreed && _controller.text == 'DELETE MY ACCOUNT';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Delete Account')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.warning_amber_rounded, size: 64, color: Colors.red),
            const SizedBox(height: 24),
            Text('Warning', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.red)),
            const SizedBox(height: 16),
            const Text('Deleting your account will permanently erase all your data, including student records, receipts, and settings. This action cannot be undone.'),
            const SizedBox(height: 32),
            const Text('To confirm, please type "DELETE MY ACCOUNT" below:'),
            const SizedBox(height: 8),
            TextField(
              controller: _controller,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'DELETE MY ACCOUNT',
              ),
            ),
            const SizedBox(height: 16),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('I understand this cannot be undone'),
              value: _agreed,
              onChanged: (val) => setState(() => _agreed = val ?? false),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _canDelete ? () {} : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Delete Account'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
