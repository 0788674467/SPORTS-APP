import 'package:flutter/material.dart';

class MatchConsole extends StatelessWidget {
  const MatchConsole({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Ref Match Console"),
        backgroundColor: Colors.red[900],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
            color: Colors.red[900],
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildScoreCol("Lions FC", 2),
                const Text("VS", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                _buildScoreCol("Eagles Utd", 1),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.timer, color: Colors.red),
                const SizedBox(width: 8),
                Text("67:45", style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Colors.red, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              padding: const EdgeInsets.all(16),
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              children: [
                _buildEventBtn(context, Icons.sports_soccer, "GOAL", Colors.green),
                _buildEventBtn(context, Icons.rectangle, "YELLOW CARD", Colors.yellow[700]!),
                _buildEventBtn(context, Icons.rectangle, "RED CARD", Colors.red),
                _buildEventBtn(context, Icons.swap_horiz, "SUBSTITUTION", Colors.blue),
                _buildEventBtn(context, Icons.pause, "MATCH PAUSE", Colors.orange),
                _buildEventBtn(context, Icons.stop, "FULL TIME", Colors.black),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreCol(String team, int score) {
    return Column(
      children: [
        Text(team, style: const TextStyle(color: Colors.white, fontSize: 18)),
        Text(score.toString(), style: const TextStyle(color: Colors.white, fontSize: 64, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildEventBtn(BuildContext context, IconData icon, String label, Color color) {
    return ElevatedButton(
      onPressed: () {},
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.all(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 32),
          const SizedBox(height: 8),
          Text(label, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
        ],
      ),
    );
  }
}
