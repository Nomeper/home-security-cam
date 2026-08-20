import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'role_selection_screen.dart';
import 'security_page.dart';
import 'services/device_owner_service.dart';
import 'app_launch.dart';
import 'utils.dart';

class AppIdInputScreen extends StatefulWidget {
  const AppIdInputScreen({super.key});

  @override
  State<AppIdInputScreen> createState() => _AppIdInputScreenState();
}

class _AppIdInputScreenState extends State<AppIdInputScreen> {
  final TextEditingController _controller = TextEditingController();
  bool _isValid = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text == null) return;
    _controller.text = data!.text!;
    setState(() => _isValid = _controller.text.trim().length > 10);
  }

  Future<void> _openAgoraWebsite() async {
    try {
      await DeviceOwnerService().openUrl(kAgoraWebsiteUrl);
    } on MissingPluginException {
      // Tests and platforms without the Android channel.
    } on PlatformException catch (error) {
      debugPrint('Open Agora site failed: $error');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossibile aprire il sito Agora.')),
      );
    }
  }

  Future<void> _saveAppId() async {
    final appId = _controller.text.trim();
    if (appId.length < 10) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('agora_app_id', appId);

    final isDeviceOwner = await DeviceOwnerService().isManagedCamera();
    if (!mounted) return;
    if (isDeviceOwner) {
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
      return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configurazione iniziale')),
      body: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.videocam, size: 60, color: Colors.blueAccent),
            const SizedBox(height: 24),
            const Text(
              'Inserisci Agora App ID',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              'Stesso codice su visore e telecamera. Lo trovi gratis nella console Agora.io, progetto di test senza token.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
            ),
            const SizedBox(height: 30),
            TextField(
              controller: _controller,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                labelText: 'App ID',
                hintText: 'Incolla qui...',
                filled: true,
                fillColor: const Color(0xFF1E1E1E),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.paste),
                  onPressed: _pasteFromClipboard,
                ),
              ),
              onChanged: (v) => setState(() => _isValid = v.trim().length > 10),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: GestureDetector(
                onTap: _openAgoraWebsite,
                child: Text(
                  'www.agora.io',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blueAccent.withValues(alpha: 0.85),
                    decoration: TextDecoration.underline,
                    decorationColor: Colors.blueAccent.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isValid ? _saveAppId : null,
                child: const Text('SALVA E CONTINUA'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
