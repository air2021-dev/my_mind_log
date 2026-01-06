import 'package:flutter/material.dart';
import 'theme.dart';
import '../features/entry/presentation/home_screen.dart';

class MyMindLogApp extends StatelessWidget {
  const MyMindLogApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'My Mind Log',
      debugShowCheckedModeBanner: false,
      theme: buildWarmTheme(),
      home: const HomeScreen(),
    );
  }
}