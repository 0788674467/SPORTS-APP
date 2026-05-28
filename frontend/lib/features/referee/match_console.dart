import 'package:flutter/material.dart';

class MatchConsole extends StatelessWidget {
  const MatchConsole({super.key});

  @override
  Widget build(BuildContext context) {
    final ss = MediaQuery.of(context).size.shortestSide;
    return Scaffold(
      appBar: AppBar(
        title: const Text("Ref Match Console"),
        backgroundColor: Colors.red[900],
      ),
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.symmetric(
              vertical: (ss * 0.07).clamp(16.0, 32.0),
              horizontal: 16,
            ),
            color: Colors.red[900],
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Expanded(child: _buildScoreCol(context, "Lions FC", 2)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      "VS",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: (ss * 0.055).clamp(16.0, 26.0),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                Expanded(child: _buildScoreCol(context, "Eagles Utd", 1)),
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
                Text(
                  "67:45",
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
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

  Widget _buildScoreCol(BuildContext context, String team, int score) {
    final ss = MediaQuery.of(context).size.shortestSide;
    return Column(
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            team,
            style: TextStyle(
              color: Colors.white,
              fontSize: (ss * 0.045).clamp(12.0, 20.0),
            ),
          ),
        ),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            score.toString(),
            style: TextStyle(
              color: Colors.white,
              fontSize: (ss * 0.15).clamp(36.0, 64.0),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEventBtn(BuildContext context, IconData icon, String label, Color color) {
    final ss = MediaQuery.of(context).size.shortestSide;
    return ElevatedButton(
      onPressed: () {},
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.all(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: (ss * 0.07).clamp(20.0, 36.0)),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: (ss * 0.03).clamp(9.0, 13.0),
            ),
          ),
        ],
      ),
    );
  }
}
