// lib/role_selection_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'utils.dart';
import 'home_setup_screen.dart';
import 'splash_screen.dart';

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  }

  Future<void> _selectRole(BuildContext context, DeviceRole role) async {
    if (role != DeviceRole.viewer) {
      final status = await Permission.camera.request();
      if (!context.mounted) return;
      if (!status.isGranted) {
        _showCameraPermissionIssue(context, status);
        return;
      }
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('role', role.toString());

    if (!context.mounted) return;

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => HomeSetupScreen(role: role)),
    );
  }

  void _showCameraPermissionIssue(
    BuildContext context,
    PermissionStatus status,
  ) {
    final needsSettings = status.isPermanentlyDenied || status.isRestricted;
    final message = needsSettings
        ? 'L’accesso alla fotocamera è bloccato. Abilitalo nelle impostazioni.'
        : 'L’accesso alla fotocamera è necessario per usare questo dispositivo come telecamera.';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        action: needsSettings
            ? const SnackBarAction(
                label: 'IMPOSTAZIONI',
                onPressed: openAppSettings,
              )
            : null,
      ),
    );
  }

  Future<void> _resetAppId(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.remove('role'),
      prefs.remove('home_id'),
      prefs.remove('device_id'),
      // Legacy key used before the server-side RTC session flow.
      prefs.remove('agora_app_id'),
      for (final key in prefs.getKeys().where((key) => key.startsWith('cam_name_')))
        prefs.remove(key),
    ]);
    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const SplashScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(title: const Text('Scegli Ruolo')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _RoleCard(
              title: "VISORE",
              subtitle: "Monitora le camere (con Intercom)",
              icon: Icons.visibility,
              color: Colors.greenAccent,
              onTap: () => _selectRole(context, DeviceRole.viewer),
            ),
            const SizedBox(height: 30),
            const Text("--- OPPURE TELECAMERA ---",
                style: TextStyle(color: Colors.white54, fontSize: 12)),
            const SizedBox(height: 15),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                _MiniRoleCard("CAM 1", Colors.blue,
                    () => _selectRole(context, DeviceRole.camera1)),
                _MiniRoleCard("CAM 2", Colors.purple,
                    () => _selectRole(context, DeviceRole.camera2)),
                _MiniRoleCard("CAM 3", Colors.orange,
                    () => _selectRole(context, DeviceRole.camera3)),
                _MiniRoleCard("CAM 4", Colors.red,
                    () => _selectRole(context, DeviceRole.camera4)),
                _MiniRoleCard("CAM 5", Colors.teal,
                    () => _selectRole(context, DeviceRole.camera5)),
                _MiniRoleCard("CAM 6", Colors.pink,
                    () => _selectRole(context, DeviceRole.camera6)),
              ],
            ),
            const SizedBox(height: 40),
            TextButton.icon(
              icon: const Icon(Icons.delete_forever,
                  size: 16, color: Colors.grey),
              label: const Text("Reimposta pairing e ruolo",
                  style: TextStyle(color: Colors.grey)),
              onPressed: () => _resetAppId(context),
            )
          ],
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _RoleCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$title. $subtitle',
      child: InkWell(
        onTap: onTap,
        child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
          child: Row(children: [
          Icon(icon, color: color, size: 40),
          const SizedBox(width: 20),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            Text(subtitle, style: const TextStyle(color: Colors.grey)),
          ])
          ]),
        ),
      ),
    );
  }
}

class _MiniRoleCard extends StatelessWidget {
  final String title;
  final Color color;
  final VoidCallback onTap;

  const _MiniRoleCard(this.title, this.color, this.onTap);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Seleziona $title',
      child: InkWell(
        onTap: onTap,
        child: Container(
        width: 100,
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
          child: Column(
          children: [
            Icon(Icons.videocam, color: color),
            const SizedBox(height: 8),
            Text(title,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ],
          ),
        ),
      ),
    );
  }
}
