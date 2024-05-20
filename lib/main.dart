import 'package:flutter/material.dart';
import 'package:voice_assistant/pages/home_page.dart';
import 'package:voice_assistant/pages/map_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Flutter Demo',
      debugShowCheckedModeBanner: false,
      home:  HomePage(),
    );
  }
}
