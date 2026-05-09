import 'package:flutter/material.dart';

class StandingsTable extends StatelessWidget {
  const StandingsTable({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("League Standings")),
      body: SingleChildScrollView(
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Pos')),
            DataColumn(label: Text('Team')),
            DataColumn(label: Text('P')),
            DataColumn(label: Text('GD')),
            DataColumn(label: Text('Pts')),
          ],
          rows: List.generate(8, (index) {
            return DataRow(cells: [
              DataCell(Text('${index + 1}')),
              DataCell(Text('Team ${index + 1}')),
              DataCell(const Text('12')),
              DataCell(const Text('+5')),
              DataCell(Text('${30 - index * 3}', style: const TextStyle(fontWeight: FontWeight.bold))),
            ]);
          }),
        ),
      ),
    );
  }
}
