// lib/splash_screen.dart
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'utils.dart';
import 'role_selection_screen.dart';
import 'security_page.dart';
import 'sign_in_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkData();
  }

  Future<void> _checkData() async {
    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;

    if (FirebaseAuth.instance.currentUser == null) {
      _navigate(const SignInScreen());
      return;
    }

    // The legacy role is only a UI preference. RTC authorization is issued by
    // the Firebase Function after the device has been paired.
    final prefs = await SharedPreferences.getInstance();
    final String? savedRole = prefs.getString('role');
    if (savedRole != null) {
      DeviceRole role = stringToRole(savedRole);
      _navigate(SecurityPage(role: role));
    } else {
      _navigate(const RoleSelectionScreen());
    }
  }

  void _navigate(Widget page) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => page),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.security, size: 80, color: Colors.blueAccent),
            SizedBox(height: 20),
            CircularProgressIndicator(color: Colors.blueAccent),
          ],
        ),
      ),
    );
  }
}
