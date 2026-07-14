import 'package:flutter/material.dart';
import 'package:marga_app/screens/login/login_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home Screen'),
      ),
      body: ListTile(
        onTap: () {
          Navigator.of(context).push(
           MaterialPageRoute<void>(
            builder: (context) => const LoginScreen(),
    ),
  );
        },
      ),
    );
  }
}