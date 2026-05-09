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
    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        radius: 20,
        backgroundImage: imageUrl != null ? NetworkImage(imageUrl!) : null,
        child: imageUrl == null ? Text(jerseyNumber.toString()) : null,
      ),
      title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(position),
      trailing: trailing ?? const Icon(Icons.chevron_right),
    );
  }
}
