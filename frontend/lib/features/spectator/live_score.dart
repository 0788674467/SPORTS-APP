import 'package:flutter/material.dart';

class LiveScore extends StatelessWidget {
  final String matchId;
  const LiveScore({super.key, required this.matchId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Live Match")),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            color: Colors.grey[100],
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildTeam("Lions FC"),
                const Text("2 - 1", style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold)),
                _buildTeam("Eagles Utd"),
              ],
            ),
          ),
          const Expanded(
            child: DefaultTabController(
              length: 3,
              child: Column(
                children: [
                   TabBar(
                    tabs: [
                      Tab(text: "Timeline"),
                      Tab(text: "Lineups"),
                      Tab(text: "Stats"),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        Center(child: Text("Timeline Data")),
                        Center(child: Text("Lineup Data")),
                        Center(child: Text("Match Stats")),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeam(String name) {
    return Column(
      children: [
        const CircleAvatar(radius: 32, child: Icon(Icons.shield, size: 32)),
        const SizedBox(height: 8),
        Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }
}
