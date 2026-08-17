import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'security_page.dart';
import 'services/home_access_service.dart';
import 'utils.dart';

class HomeSetupScreen extends StatefulWidget {
  const HomeSetupScreen({super.key, required this.role});

  final DeviceRole role;

  @override
  State<HomeSetupScreen> createState() => _HomeSetupScreenState();
}

class _HomeSetupScreenState extends State<HomeSetupScreen> {
  final _homeIdController = TextEditingController();
  final _codeController = TextEditingController();
  final _service = HomeAccessService();
  bool _busy = false;
  String? _ownedHomeId;
  PairingCode? _pairingCode;

  bool get _isCamera => widget.role != DeviceRole.viewer;

  @override
  void dispose() {
    _homeIdController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _createHome() async {
    await _run(() async {
      final homeId = await _service.createHome();
      if (!mounted) return;
      setState(() => _ownedHomeId = homeId);
    });
  }

  Future<void> _redeemCode() async {
    await _run(() async {
      final homeId = _homeIdController.text.trim();
      final code = _codeController.text.trim().toUpperCase();
      if (homeId.isEmpty || code.isEmpty) {
        throw const FormatException('Inserisci ID casa e codice di abbinamento.');
      }
      final deviceId =
          await _service.redeemPairingCode(homeId: homeId, code: code);
      if (_isCamera && deviceId == null) {
        throw const FormatException('Questo codice non è valido per una telecamera.');
      }
      await _saveAndContinue(
        homeId: homeId,
        deviceId: deviceId ?? 'viewer',
      );
    });
  }

  Future<void> _createPairingCode(String target) async {
    final homeId = _ownedHomeId;
    if (homeId == null) return;
    await _run(() async {
      final pairingCode =
          await _service.createPairingCode(homeId: homeId, target: target);
      if (mounted) setState(() => _pairingCode = pairingCode);
    });
  }

  Future<void> _saveAndContinue({
    required String homeId,
    required String deviceId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('home_id', homeId);
    await prefs.setString('device_id', deviceId);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => SecurityPage(role: widget.role)),
    );
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$error'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOwnerViewer = !_isCamera && _ownedHomeId != null;
    return Scaffold(
      appBar: AppBar(title: const Text('Configura casa sicura')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                _isCamera ? 'Abbina telecamera' : 'Configura visore',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              const Text(
                'Ogni dispositivo deve usare il proprio account e un codice '
                'di abbinamento monouso.',
              ),
              const SizedBox(height: 24),
              if (!_isCamera && !isOwnerViewer)
                FilledButton(
                  onPressed: _busy ? null : _createHome,
                  child: const Text('CREA UNA NUOVA CASA'),
                ),
              if (!_isCamera && !isOwnerViewer) const SizedBox(height: 16),
              if (isOwnerViewer) ...[
                SelectableText('ID casa: $_ownedHomeId'),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: _busy
                      ? null
                      : () => _createPairingCode('camera'),
                  child: const Text('GENERA CODICE TELECAMERA'),
                ),
                OutlinedButton(
                  onPressed: _busy
                      ? null
                      : () => _createPairingCode('viewer'),
                  child: const Text('GENERA CODICE VISORE'),
                ),
                if (_pairingCode != null) ...[
                  const SizedBox(height: 16),
                  SelectableText(
                    'Codice ${_pairingCode!.target}: ${_pairingCode!.code}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    'Scade alle ${TimeOfDay.fromDateTime(_pairingCode!.expiresAt).format(context)}',
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _busy
                      ? null
                      : () => _saveAndContinue(
                            homeId: _ownedHomeId!,
                            deviceId: 'viewer',
                          ),
                  child: const Text('CONTINUA COME VISORE'),
                ),
              ] else ...[
                const Divider(height: 32),
                TextField(
                  controller: _homeIdController,
                  autocorrect: false,
                  decoration: const InputDecoration(labelText: 'ID casa'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _codeController,
                  autocorrect: false,
                  textCapitalization: TextCapitalization.characters,
                  decoration:
                      const InputDecoration(labelText: 'Codice di abbinamento'),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _busy ? null : _redeemCode,
                  child: Text(
                    _isCamera ? 'ABBINA TELECAMERA' : 'COLLEGA VISORE',
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
