import 'package:flutter/material.dart';
import 'ble_scanner.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: BleScanner(),
    );
  }
}
