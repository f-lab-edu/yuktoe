import 'package:flutter/material.dart';
import 'package:yuktoe/login/views/login_view.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '내꿈은육퇴',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2B7FFF)),
      ),
      home: const LoginView(),
    );
  }
}
