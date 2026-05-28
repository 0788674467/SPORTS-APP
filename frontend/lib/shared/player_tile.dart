import 'package:flutter/material.dart';

class PlayerTile extends StatelessWidget {
  final String name;
  final String position;
  final int jerseyNumber;
  final String? imageUrl;
  final VoidCallback? onTap;
  final Widget? trailing;

  const PlayerTile({
    super.key,
    required this.name,
    required this.position,
    required this.jerseyNumber,
    this.imageUrl,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final avatarR = (MediaQuery.of(context).size.shortestSide * 0.055).clamp(16.0, 24.0);
    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        radius: avatarR,
        backgroundImage: imageUrl != null ? NetworkImage(imageUrl!) : null,
        child: imageUrl == null
            ? Text(
                jerseyNumber.toString(),
                style: TextStyle(fontSize: (avatarR * 0.7).clamp(10.0, 16.0)),
              )
            : null,
      ),
      title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(position),
      trailing: trailing ?? const Icon(Icons.chevron_right),
    );
  }
}
