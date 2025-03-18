import 'package:flutter/material.dart';

class LocationPickerDialog extends StatelessWidget {
  final String initialLocation;

  const LocationPickerDialog({super.key, required this.initialLocation});

  @override
  Widget build(BuildContext context) {
    List<String> locations = [
      "SM-1-1", "SM-1-2", "SM-1-3",
      "SM-2-1", "SM-2-2", "SM-2-3",
      "SM-3-1", "SM-3-2", "SM-3-3"
    ];

    return AlertDialog(
      title: const Text("Wybierz lokalizację"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: locations.map((location) {
          return RadioListTile(
            title: Text(location),
            value: location,
            groupValue: initialLocation,
            onChanged: (value) {
              Navigator.pop(context, value);
            },
          );
        }).toList(),
      ),
    );
  }
}
