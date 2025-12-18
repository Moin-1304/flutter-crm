import 'package:flutter/material.dart';

class ExpenseListScreen extends StatelessWidget {
  const ExpenseListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: 12,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) => ListTile(
        leading: const Icon(Icons.receipt_long),
        title: Text('Expense #${index + 1}'),
        subtitle: const Text('Rs 1,250 • Travel'),
      ),
    );
  }
}

class ExpenseManagerReviewList extends StatelessWidget {
  const ExpenseManagerReviewList({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 7,
      itemBuilder: (context, index) => Card(
        child: ListTile(
          leading: const Icon(Icons.verified_user_outlined),
          title: Text('Approve Expense #${index + 1}'),
          subtitle: const Text('Employee: Jane • Amount: Rs 980'),
          trailing: Wrap(
            spacing: 8,
            children: [
              IconButton(icon: const Icon(Icons.check, color: Colors.green), onPressed: () {}),
              IconButton(icon: const Icon(Icons.close, color: Colors.redAccent), onPressed: () {}),
            ],
          ),
        ),
      ),
    );
  }
}


