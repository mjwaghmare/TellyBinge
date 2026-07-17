import 'package:flutter/material.dart';
import '../../../../main.dart'; // To navigate to AuthGate

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const AuthGate()),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFFC107), // Amber 500
              Color(0xFFFFEB3B), // Yellow 500
            ],
          ),
        ),
        child: Center(
          child: Hero(
            tag: 'app_logo',
            child: Image.asset(
              'assets/images/logo.png',
              width: 160,
              height: 160,
            ),
          ),
        ),
      ),
    );
  }
}
