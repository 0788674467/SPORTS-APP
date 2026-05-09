import 'package:flutter/material.dart';

class FixtureList extends StatelessWidget {
  const FixtureList({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Season Fixtures")),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 10,
        itemBuilder: (context, index) {
          return Card(
            child: ListTile(
              title: Text("Match Day ${index + 1}"),
              subtitle: const Text("Saturday, 15:00"),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {},
            ),
          );
        },
      ),
    );
  }
}
