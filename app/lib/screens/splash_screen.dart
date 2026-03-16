// lib/screens/splash_screen.dart
import 'package:flutter/material.dart';
import 'dart:async';
import '../main.dart'; 

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Timer(Duration(seconds: 3), () {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => AuthWrapper()), 
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Spacer(),
            Icon(Icons.incomplete_circle, size: 80, color: Colors.black), 
            SizedBox(height: 20),
            Text(
              "Read Deeper. Think Clearer.",
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[700],
                fontFamily: 'Roboto', 
              ),
            ),
            Spacer(),
            Text(
              "Refmind",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            Text(
              "Version 1.0",
              style: TextStyle(color: Colors.grey),
            ),
            SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}