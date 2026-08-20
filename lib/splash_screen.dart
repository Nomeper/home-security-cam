// lib/splash_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_id_input_screen.dart';
import 'app_launch.dart';
import 'role_selection_screen.dart';
import 'security_page.dart';
import 'services/device_owner_service.dart';
import 'services/startup_permissions.dart';
import 'utils.dart';

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
    await StartupPermissions.requestAll();
    if (!mounted) return;
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();
    final appId = prefs.getString('agora_app_id');
    final isDeviceOwner = await DeviceOwnerService().isManagedCamera();
    if (isDeviceOwner) {
      await prefs.setString(
        'role',
        AppLaunchDecision.roleForDeviceOwner().toString(),
      );
    }

    final route = AppLaunchDecision.decide(
      hasAppId: appId != null && appId.isNotEmpty,
      isDeviceOwner: isDeviceOwner,
      role: prefs.getString('role'),
    );

    if (!mounted) return;
    switch (route) {
      case AppLaunchRoute.appId:
        _navigate(const AppIdInputScreen());
      case AppLaunchRoute.roleSelection:
        _navigate(const RoleSelectionScreen());
      case AppLaunchRoute.security:
        _navigate(SecurityPage(role: stringToRole(prefs.getString('role'))));
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
