// lib/role_selection_screen.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_launch.dart';
import 'channel_encryption.dart';
import 'security_page.dart';
import 'services/device_owner_service.dart';
import 'services/role_occupancy_probe.dart';
import 'splash_screen.dart';
import 'utils.dart';

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  RoleOccupancyProbe? _probe;
  Set<DeviceRole> _occupiedRoles = {};
  bool _checkingOccupancy = true;
  bool _selecting = false;
  int _probeSession = 0;

  static const _cameraRoles = [
    DeviceRole.camera1,
    DeviceRole.camera2,
    DeviceRole.camera3,
    DeviceRole.camera4,
    DeviceRole.camera5,
    DeviceRole.camera6,
  ];

  static const _cameraColors = [
    Colors.blue,
    Colors.purple,
    Colors.orange,
    Colors.red,
    Colors.teal,
    Colors.pink,
  ];

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    unawaited(_boot());
  }

  @override
  void dispose() {
    unawaited(_probe?.stop());
    super.dispose();
  }

  Future<void> _boot() async {
    if (await DeviceOwnerService().isManagedCamera()) {
      await _redirectManagedCamera();
      return;
    }
    await _refreshOccupancy();
  }

  /// Ricontrolla i ruoli occupati ogni volta che si entra in questa schermata.
  Future<void> _refreshOccupancy() async {
    final session = ++_probeSession;
    await _probe?.stop();
    _probe = null;
    if (!mounted || session != _probeSession) return;
    setState(() {
      _occupiedRoles = {};
      _checkingOccupancy = true;
      _selecting = false;
    });
    // Lascia rilasciare l'engine Agora della sessione precedente (es. uscita visore).
    await Future<void>.delayed(const Duration(milliseconds: 450));
    if (!mounted || session != _probeSession) return;
    await _startOccupancyProbe(session: session);
  }

  Future<void> _redirectManagedCamera() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'role',
      AppLaunchDecision.roleForDeviceOwner().toString(),
    );
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => SecurityPage(
          role: AppLaunchDecision.roleForDeviceOwner(),
        ),
      ),
    );
  }

  Future<void> _startOccupancyProbe({required int session}) async {
    final prefs = await SharedPreferences.getInstance();
    final appId = prefs.getString('agora_app_id');
    final channelKey = prefs.getString(kChannelKeyPref);
    if (!mounted || session != _probeSession) return;
    if (appId == null ||
        appId.isEmpty ||
        !isValidChannelKey(channelKey)) {
      setState(() => _checkingOccupancy = false);
      return;
    }

    final probe = RoleOccupancyProbe(
      onOccupiedRoles: (occupied) {
        if (!mounted || session != _probeSession) return;
        setState(() => _occupiedRoles = occupied);
      },
      onReady: () {
        if (!mounted || session != _probeSession) return;
        setState(() => _checkingOccupancy = false);
      },
    );
    _probe = probe;
    unawaited(probe.start(appId, channelKey: channelKey!));
    Future<void>.delayed(const Duration(seconds: 8), () {
      if (!mounted ||
          session != _probeSession ||
          !_checkingOccupancy) {
        return;
      }
      setState(() => _checkingOccupancy = false);
    });
  }

  bool _isOccupied(DeviceRole role) => _occupiedRoles.contains(role);

  Future<void> _selectRole(BuildContext context, DeviceRole role) async {
    if (_selecting || _isOccupied(role)) return;

    if (role != DeviceRole.viewer) {
      final status = await Permission.camera.request();
      if (!context.mounted) return;
      if (!status.isGranted) {
        _showCameraPermissionIssue(context, status);
        return;
      }
    }

    _selecting = true;
    await _probe?.stop();
    _probe = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('role', role.toString());

    if (!context.mounted) return;

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => SecurityPage(role: role)),
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
    await _probe?.stop();
    _probe = null;
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.remove('role'),
      prefs.remove('home_id'),
      prefs.remove('device_id'),
      prefs.remove('agora_app_id'),
      prefs.remove(kChannelKeyPref),
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
    final viewerOccupied = _isOccupied(DeviceRole.viewer);
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(title: const Text('Scegli Ruolo')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _RoleCard(
              title: 'VISORE',
              subtitle: 'Monitora le telecamere in tempo reale',
              icon: Icons.visibility,
              color: Colors.greenAccent,
              occupied: viewerOccupied,
              onTap: () => _selectRole(context, DeviceRole.viewer),
            ),
            const SizedBox(height: 30),
            const Text('--- OPPURE TELECAMERA ---',
                style: TextStyle(color: Colors.white54, fontSize: 12)),
            const SizedBox(height: 15),
            for (var row = 0; row < 2; row++) ...[
              if (row > 0) const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var col = 0; col < 3; col++) ...[
                    if (col > 0) const SizedBox(width: 10),
                    _MiniRoleCard(
                      'CAM ${row * 3 + col + 1}',
                      _cameraColors[row * 3 + col],
                      () => _selectRole(
                        context,
                        _cameraRoles[row * 3 + col],
                      ),
                      occupied: _isOccupied(_cameraRoles[row * 3 + col]),
                    ),
                  ],
                ],
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              height: 24,
              width: double.infinity,
              child: Opacity(
                opacity: _checkingOccupancy ? 1 : 0,
                child: const Text(
                  'Controllo chi è già nel canale…',
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.white54, fontSize: 13),
                ),
              ),
            ),
            const SizedBox(height: 40),
            TextButton.icon(
              icon: const Icon(Icons.delete_forever,
                  size: 16, color: Colors.grey),
              label: const Text('Reimposta App ID, chiave e ruolo',
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
  final bool occupied;
  final VoidCallback onTap;

  const _RoleCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.occupied,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final displayColor = occupied ? Colors.grey : color;
    return Semantics(
      button: !occupied,
      enabled: !occupied,
      label: occupied ? '$title. già in uso' : '$title. $subtitle',
      child: Opacity(
        opacity: occupied ? 0.45 : 1,
        child: InkWell(
          onTap: occupied ? null : onTap,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: displayColor.withValues(alpha: 0.5)),
            ),
            child: Row(children: [
              Icon(icon, color: displayColor, size: 40),
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
      ),
    );
  }
}

class _MiniRoleCard extends StatelessWidget {
  final String title;
  final Color color;
  final bool occupied;
  final VoidCallback onTap;

  const _MiniRoleCard(this.title, this.color, this.onTap, {this.occupied = false});

  @override
  Widget build(BuildContext context) {
    final displayColor = occupied ? Colors.grey : color;
    return Semantics(
      button: !occupied,
      enabled: !occupied,
      label: occupied ? '$title già in uso' : 'Seleziona $title',
      child: Opacity(
        opacity: occupied ? 0.45 : 1,
        child: InkWell(
          onTap: occupied ? null : onTap,
          child: Container(
            width: 100,
            height: 96,
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: displayColor.withValues(alpha: 0.5)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.videocam, color: displayColor),
                const SizedBox(height: 8),
                Text(title,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
