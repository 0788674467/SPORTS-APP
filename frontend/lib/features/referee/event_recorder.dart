import 'package:flutter/material.dart';

class EventRecorder extends StatefulWidget {
  final String eventType;
  const EventRecorder({super.key, required this.eventType});

  @override
  State<EventRecorder> createState() => _EventRecorderState();
}

class _EventRecorderState extends State<EventRecorder> {
  String? _selectedPlayer;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Record ${widget.eventType}")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Select Player:", style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: 11,
                itemBuilder: (context, index) {
                  final name = "Player ${index + 1}";
                  final isSelected = _selectedPlayer == name;
                  return ListTile(
                    title: Text(name),
                    trailing: isSelected ? const Icon(Icons.check, color: Colors.green) : null,
                    onTap: () => setState(() => _selectedPlayer = name),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _selectedPlayer == null
                    ? null
                    : () {
                        // Confirm event
                      },
                child: Text("Confirm ${widget.eventType}"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
