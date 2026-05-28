import 'package:flutter/material.dart';

class ScoreCard extends StatelessWidget {
  final String homeTeam;
  final String awayTeam;
  final int homeScore;
  final int awayScore;
  final String status;
  final String? matchMinute;
  final VoidCallback? onTap;

  const ScoreCard({
    super.key,
    required this.homeTeam,
    required this.awayTeam,
    required this.homeScore,
    required this.awayScore,
    required this.status,
    this.matchMinute,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    final avatarR = (sw * 0.06).clamp(16.0, 28.0);
    final scoreFs = (sw * 0.07).clamp(20.0, 36.0);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              if (status == 'live')
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        "LIVE",
                        style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      matchMinute ?? "0'",
                      style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                         CircleAvatar(radius: avatarR, child: Icon(Icons.shield, size: avatarR * 0.7)),
                        const SizedBox(height: 8),
                        Text(homeTeam, style: const TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      "$homeScore - $awayScore",
                      style: TextStyle(fontSize: scoreFs, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                         CircleAvatar(radius: avatarR, child: Icon(Icons.shield, size: avatarR * 0.7)),
                        const SizedBox(height: 8),
                        Text(awayTeam, style: const TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                status.toUpperCase(),
                style: TextStyle(color: Colors.grey[600], fontSize: 12, letterSpacing: 1.2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
