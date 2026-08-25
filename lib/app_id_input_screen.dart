import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'role_selection_screen.dart';
import 'security_page.dart';
import 'services/device_owner_service.dart';
import 'app_launch.dart';
import 'channel_encryption.dart';
import 'utils.dart';

class AppIdInputScreen extends StatefulWidget {
  const AppIdInputScreen({super.key});

  @override
  State<AppIdInputScreen> createState() => _AppIdInputScreenState();
}

class _AppIdInputScreenState extends State<AppIdInputScreen> {
  final TextEditingController _appIdController = TextEditingController();
  final TextEditingController _keyController = TextEditingController();
  bool _obscureKey = true;
  bool _isValid = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _loadSavedValues();
  }

  Future<void> _loadSavedValues() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    _appIdController.text = prefs.getString('agora_app_id') ?? '';
    _keyController.text = prefs.getString(kChannelKeyPref) ?? '';
    _refreshValid();
  }

  @override
  void dispose() {
    _appIdController.dispose();
    _keyController.dispose();
    super.dispose();
  }

  void _refreshValid() {
    setState(() {
      _isValid = _appIdController.text.trim().length > 10 &&
          isValidChannelKey(_keyController.text);
    });
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text == null) return;
    _appIdController.text = data!.text!;
    _refreshValid();
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

  Future<void> _saveAndContinue() async {
    final appId = _appIdController.text.trim();
    final channelKey = _keyController.text.trim();
    if (appId.length < 10 || !isValidChannelKey(channelKey)) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('agora_app_id', appId);
    await prefs.setString(kChannelKeyPref, channelKey);

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
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.videocam, size: 60, color: Colors.blueAccent),
              const SizedBox(height: 24),
              const Text(
                'Inserisci App ID e chiave di casa',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text(
                'Casa Sicura usa telefoni Android come telecamere di casa. '
                'Un telefono (o il PC) è il visore: da lì vedi in diretta e '
                'scegli quali CAM accendere (fino a sei). Non è un allarme '
                'professionale: serve a guardare salotto, ingresso o cortile.\n\n'
                'Questa app ha bisogno di Agora per funzionare: non ha un server '
                'proprio, il video passa da agora.io. Registrati (gratis), crea '
                'un progetto di test e incolla qui l’App ID (è il codice API che '
                'Agora ti dà). Senza App ID visore e telecamere non si vedono.\n\n'
                'Ogni mese hai 10.000 minuti di streaming gratis.\n\n'
                'Poi scegli una chiave di casa (la inventi tu) e usala identica '
                'su visore, telecamere e PC. Non è l’App ID: cifra il video.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  height: 1.35,
                  color: Colors.white.withValues(alpha: 0.55),
                ),
              ),
              const SizedBox(height: 30),
              TextField(
                controller: _appIdController,
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(
                  labelText: 'App ID Agora',
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
                onChanged: (_) => _refreshValid(),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: GestureDetector(
                  onTap: _openAgoraWebsite,
                  child: Text(
                    'www.agora.io — registrati qui (10.000 minuti gratis al mese)',
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
              TextField(
                controller: _keyController,
                obscureText: _obscureKey,
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(
                  labelText: 'Chiave di casa',
                  hintText: '8–62 caratteri, identica sul PC',
                  filled: true,
                  fillColor: const Color(0xFF1E1E1E),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureKey ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () =>
                        setState(() => _obscureKey = !_obscureKey),
                  ),
                ),
                onChanged: (_) => _refreshValid(),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isValid ? _saveAndContinue : null,
                  child: const Text('SALVA E CONTINUA'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
