import 'package:flutter/material.dart';

class LiveScore extends StatelessWidget {
  final String matchId;
  const LiveScore({super.key, required this.matchId});

  @override
  Widget build(BuildContext context) {
    final ss = MediaQuery.of(context).size.shortestSide;
    final scoreFs = (ss * 0.12).clamp(28.0, 52.0);
    return Scaffold(
      appBar: AppBar(title: const Text("Live Match")),
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.symmetric(
              vertical: (ss * 0.055).clamp(12.0, 24.0),
              horizontal: (ss * 0.05).clamp(12.0, 24.0),
            ),
            color: Colors.grey[100],
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Expanded(child: _buildTeam(context, "Lions FC")),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      "2 - 1",
                      style: TextStyle(
                        fontSize: scoreFs,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                Expanded(child: _buildTeam(context, "Eagles Utd")),
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

  Widget _buildTeam(BuildContext context, String name) {
    final ss = MediaQuery.of(context).size.shortestSide;
    final avatarR = (ss * 0.08).clamp(20.0, 36.0);
    return Column(
      children: [
        CircleAvatar(
          radius: avatarR,
          child: Icon(Icons.shield, size: avatarR * 0.85),
        ),
        const SizedBox(height: 8),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
